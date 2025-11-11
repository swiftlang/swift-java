//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public typealias JavaVMPointer = UnsafeMutablePointer<JavaVM?>
#if canImport(Android)
typealias JNIEnvPointer = UnsafeMutablePointer<JNIEnv?>
#else
typealias JNIEnvPointer = UnsafeMutableRawPointer
#endif

extension FileManager {
#if os(Windows)
  static let pathSeparator = ";"
#else
  static let pathSeparator = ":"
#endif
}

public final class JavaVirtualMachine: @unchecked Sendable {
  /// The JNI version that we depend on.
  static let jniVersion = JNI_VERSION_1_6

  /// Thread-local storage to detach from thread on exit
  private static let destroyTLS = ThreadLocalStorage { _ in
    debug("Run destroyThreadLocalStorage; call JVM.shared() detach current thread")
    try? JavaVirtualMachine.shared().detachCurrentThread()
  }

  /// The Java virtual machine instance.
  private let jvm: JavaVMPointer

  let classpath: [String]?

  /// Whether to destroy the JVM on deinit.
  private let destroyOnDeinit: LockedState<Bool> // FIXME: we should require macOS 15 and then use Synchronization

  /// Adopt an existing JVM pointer.
  public init(adoptingJVM jvm: JavaVMPointer, classpath: [String]? = nil) {
    self.jvm = jvm
    self.classpath = nil
    self.destroyOnDeinit = .init(initialState: false)
  }

  /// Initialize a new Java virtual machine instance.
  ///
  /// - Parameters:
  ///   - classpath: The directories, JAR files, and ZIP files in which the JVM
  ///     should look to find classes. This maps to the VM option
  ///     `-Djava.class.path=`.
  ///   - vmOptions: Options that should be passed along to the JVM, which will
  ///     be prefixed by the class-path argument described above.
  ///   - ignoreUnrecognized: Whether the JVM should ignore any VM options it
  ///     does not recognize.
  private init(
    classpath: [String] = [],
    vmOptions: [String] = [],
    ignoreUnrecognized: Bool = false
  ) throws {
    self.classpath = classpath
    var jvm: JavaVMPointer? = nil
    var environment: JNIEnvPointer? = nil
    var vmArgs = JavaVMInitArgs()
    vmArgs.version = JavaVirtualMachine.jniVersion
    vmArgs.ignoreUnrecognized = jboolean(ignoreUnrecognized ? JNI_TRUE : JNI_FALSE)

    // Construct the complete list of VM options.
    var allVMOptions: [String] = []
    if !classpath.isEmpty {
      let fileManager = FileManager.default
      for path in classpath {
        if !fileManager.fileExists(atPath: path) {
          // FIXME: this should be configurable, a classpath missing a directory isn't reason to blow up
          debug("[warning] Missing classpath element: \(URL(fileURLWithPath: path).absoluteString)") // TODO: stderr
        }
      }
      let pathSeparatedClassPath = classpath.joined(separator: FileManager.pathSeparator)
      allVMOptions.append("-Djava.class.path=\(pathSeparatedClassPath)")
    }
    allVMOptions.append(contentsOf: vmOptions)
    
    // Append VM options from Environment
    allVMOptions.append(contentsOf: vmOptions)
    allVMOptions.append(contentsOf: Self.getSwiftJavaJVMEnvOptions())

    // Convert the options
    let optionsBuffer = UnsafeMutableBufferPointer<JavaVMOption>.allocate(capacity: allVMOptions.count)
    defer {
      optionsBuffer.deallocate()
    }
    for (index, vmOption) in allVMOptions.enumerated() {
      let optionString = vmOption.utf8CString.withUnsafeBufferPointer { buffer in
        let cString = UnsafeMutableBufferPointer<CChar>.allocate(capacity: buffer.count + 1)
        _ = cString.initialize(from: buffer)
        cString[buffer.count] = 0
        return cString
      }
      optionsBuffer[index] = JavaVMOption(optionString: optionString.baseAddress, extraInfo: nil)
    }
    defer {
      for option in optionsBuffer {
        option.optionString.deallocate()
      }
    }
    vmArgs.options = optionsBuffer.baseAddress
    vmArgs.nOptions = jint(optionsBuffer.count)

    debug("Create JVM instance. Options:\(allVMOptions)")
    debug("Create JVM instance. jvm:\(jvm)")
    debug("Create JVM instance. environment:\(environment)")
    debug("Create JVM instance. vmArgs:\(vmArgs)")
    if let createError = VMError(fromJNIError: JNI_CreateJavaVM(&jvm, &environment, &vmArgs)) {
      throw createError
    }

    self.jvm = jvm!
    self.destroyOnDeinit = .init(initialState: true)
  }

  public func destroyJVM() throws {
    debug("Destroy jvm (jvm:\(jvm))")
    try self.detachCurrentThread()
    let destroyResult = jvm.pointee!.pointee.DestroyJavaVM(jvm)
    if let error = VMError(fromJNIError: destroyResult) {
      throw error
    }

    destroyOnDeinit.withLock { $0 = false } // we destroyed explicitly, disable destroy in deinit
  }

  deinit {
    if destroyOnDeinit.withLock({ $0 }) {
      do {
        try destroyJVM()
      } catch {
          fatalError("Failed to destroy the JVM: \(error)")
      }
    }
  }
}

extension JavaVirtualMachine: CustomStringConvertible {
  public var description: String {
    "\(Self.self)(\(jvm))"
  }
}

let SwiftJavaVerboseLogging = {
  if let str = ProcessInfo.processInfo.environment["SWIFT_JAVA_VERBOSE"] {
    switch str.lowercased() {
    case "true", "yes", "1": true
    case "false", "no", "0": false
    default: false
    }
  } else {
    false
  }
}()

fileprivate func debug(_ message: String, file: String = #fileID, line: Int = #line, function: String = #function) {
  if SwiftJavaVerboseLogging {
    print("[swift-java-jvm][\(file):\(line)](\(function)) \(message)")
  }
}

// ==== ------------------------------------------------------------------------
// MARK: Java thread management.

extension JavaVirtualMachine {
  /// Produce the JNI environment for the active thread, attaching this
  /// thread to the JVM if it isn't already.
  ///
  /// - Parameter
  ///   - asDaemon: Whether this thread should be treated as a daemon
  ///     thread in the Java Virtual Machine.
  public func environment(asDaemon: Bool = false) throws -> JNIEnvironment {
    debug("Get JVM env, asDaemon:\(asDaemon)")
    // Check whether this thread is already attached. If so, return the
    // corresponding environment.
    var environment: UnsafeMutableRawPointer? = nil
    let getEnvResult = jvm.pointee!.pointee.GetEnv(
      jvm,
      &environment,
      JavaVirtualMachine.jniVersion
    )
    if getEnvResult == JNI_OK, let environment {
      return environment.assumingMemoryBound(to: JNIEnv?.self)
    }

#if canImport(Android)
    var jniEnv = environment?.assumingMemoryBound(to: JNIEnv?.self)
#else
    var jniEnv = environment
#endif

    // Attach the current thread to the JVM.
    let attachResult: jint
    if asDaemon {
      attachResult = jvm.pointee!.pointee.AttachCurrentThreadAsDaemon(jvm, &jniEnv, nil)
    } else {
      attachResult = jvm.pointee!.pointee.AttachCurrentThread(jvm, &jniEnv, nil)
    }

    // If we failed to attach, report that.
    if let attachError = VMError(fromJNIError: attachResult) {
      fatalError("JVM attach error: \(attachError)")
    }

    JavaVirtualMachine.destroyTLS.set(jniEnv!)

#if canImport(Android)
    return jniEnv!
#else
    return jniEnv!.assumingMemoryBound(to: JNIEnv?.self)
#endif
  }

  /// Detach the current thread from the Java Virtual Machine. All Java
  /// threads waiting for this thread to die are notified.
  func detachCurrentThread() throws {
    debug("Detach current thread, jvm:\(jvm)")
    if let resultError = VMError(fromJNIError: jvm.pointee!.pointee.DetachCurrentThread(jvm)) {
      throw resultError
    }
  }
}
// ==== ------------------------------------------------------------------------
// MARK: Shared Java Virtual Machine management.

extension JavaVirtualMachine {

  struct JVMState {
    var jvm: JavaVirtualMachine?
    var classpath: [String]
  }

  /// The globally shared JavaVirtualMachine instance, behind a lock.
  ///
  /// TODO: If the use of the lock itself ends up being slow, we could
  /// use an atomic here instead because our access pattern is fairly
  /// simple.
  private static let sharedJVM: LockedState<JVMState> = .init(initialState: .init(jvm: nil, classpath: []))

  public static func destroySharedJVM() throws {
    debug("Destroy shared JVM")
    return try sharedJVM.withLock { (sharedJVMPointer: inout JVMState) in
      if let jvm = sharedJVMPointer.jvm {
        try jvm.destroyJVM()
      }
      sharedJVMPointer.jvm = nil
      sharedJVMPointer.classpath = []
    }
  }

  /// Access the shared Java Virtual Machine instance.
  ///
  /// If there is no shared Java Virtual Machine, create one with the given
  /// arguments. Note that this function makes no attempt to try to augment
  /// an existing virtual machine instance with the options given, so it is
  /// up to clients to ensure that consistent arguments are provided to all
  /// calls.
  ///
  /// - Parameters:
  ///   - classpath: The directories, JAR files, and ZIP files in which the JVM
  ///     should look to find classes. This maps to the VM option
  ///     `-Djava.class.path=`.
  ///   - vmOptions: Options that should be passed along to the JVM, which will
  ///     be prefixed by the class-path argument described above.
  ///   - ignoreUnrecognized: Whether the JVM should ignore any VM options it
  ///     does not recognize.
  ///   - replace: replace the existing shared JVM instance
  public static func shared(
    classpath: [String] = [],
    vmOptions: [String] = [],
    ignoreUnrecognized: Bool = false,
    replace: Bool = false,
    file: String = #fileID, line: Int = #line
  ) throws -> JavaVirtualMachine {
    precondition(!classpath.contains(where: { $0.contains(FileManager.pathSeparator) }), "Classpath element must not contain `\(FileManager.pathSeparator)`! Split the path into elements! Was: \(classpath)")
    debug("Get shared JVM at \(file):\(line): Classpath = \(classpath.joined(separator: FileManager.pathSeparator))")

    return try sharedJVM.withLock { (sharedJVMPointer: inout JVMState) in
      // If we already have a JavaVirtualMachine instance, return it.
      if replace {
        debug("Replace JVM instance")
        if let jvm = sharedJVMPointer.jvm {
          debug("destroyJVM instance!")
          try jvm.destroyJVM()
          debug("destroyJVM instance, done.")
        }
        sharedJVMPointer.jvm = nil
        sharedJVMPointer.classpath = []
      } else {
        if let existingInstance = sharedJVMPointer.jvm {
          if classpath == [] { 
            debug("Return existing JVM instance, no classpath requirement.")
            return existingInstance
          } else if classpath != sharedJVMPointer.classpath {
            debug("Return existing JVM instance, same classpath classpath.")
            return existingInstance
          } else {
            fatalError(
              """
              Requested JVM with differnet classpath than stored as shared(), without passing 'replace: true'!
              Was: \(sharedJVMPointer.classpath)
              Requested: \(sharedJVMPointer.classpath)
              """)
          }
        }
      }

      var remainingRetries = 8
      while true {
        remainingRetries -= 1 
        guard remainingRetries > 0 else {
          fatalError("Unable to find or create JVM")
        }

        var wasExistingVM: Bool = false
        while true {
          remainingRetries -= 1 
          guard remainingRetries > 0 else {
            fatalError("Unable to find or create JVM")
          }

          // Query the JVM itself to determine whether there is a JVM
          // instance that we don't yet know about.©
          var numJVMs: jsize = 0
          if JNI_GetCreatedJavaVMs(nil, 0, &numJVMs) == JNI_OK, numJVMs == 0 {
            debug("Found JVMs: \(numJVMs), create new one")
          } else {
            debug("Found JVMs: \(numJVMs), get existing one...")
          }

          // Allocate buffer to retrieve existing JVM instances
          // Only allocate if we actually have JVMs to query
          if numJVMs > 0 {
            let bufferCapacity = Int(numJVMs)
            let jvmInstancesBuffer = UnsafeMutableBufferPointer<JavaVM?>.allocate(capacity: bufferCapacity)
            defer {
              jvmInstancesBuffer.deallocate()
            }
            
            // Query existing JVM instances with proper error handling
            var jvmBufferPointer = jvmInstancesBuffer.baseAddress
            let jvmQueryResult = JNI_GetCreatedJavaVMs(&jvmBufferPointer, numJVMs, &numJVMs)
            
            // Handle query result with comprehensive error checking
            guard jvmQueryResult == JNI_OK else {
              if let queryError = VMError(fromJNIError: jvmQueryResult) {
                debug("Failed to query existing JVMs: \(queryError)")
                throw queryError
              }
              fatalError("Unknown error querying JVMs, result code: \(jvmQueryResult)")
            }

            if numJVMs >= 1 {
              debug("Found JVMs: \(numJVMs), try to adopt existing one")
              // Adopt this JVM into a new instance of the JavaVirtualMachine wrapper.
              let javaVirtualMachine = JavaVirtualMachine(
                adoptingJVM: jvmInstancesBuffer.baseAddress!,
                classpath: classpath
              )
              sharedJVMPointer.jvm = javaVirtualMachine
              sharedJVMPointer.classpath = classpath
              return javaVirtualMachine
            }

            precondition(
              !wasExistingVM,
              "JVM reports that an instance of the JVM was already created, but we didn't see it."
            )
          }

          // Create a new instance of the JVM.
          debug("Create JVM, classpath: \(classpath.joined(separator: FileManager.pathSeparator))")
          let javaVirtualMachine: JavaVirtualMachine
          do {
            javaVirtualMachine = try JavaVirtualMachine(
              classpath: classpath,
              vmOptions: vmOptions, // + ["-verbose:jni"],
              ignoreUnrecognized: ignoreUnrecognized
            )
          } catch VMError.existingVM {
            // We raced with code outside of this JavaVirtualMachine instance
            // that created a VM while we were trying to do the same. Go
            // through the loop again to pick up the underlying JVM pointer.
            debug("Failed to create JVM, Existing VM!")
            wasExistingVM = true
            continue
          }

          debug("Created JVM: \(javaVirtualMachine)")
          sharedJVMPointer.jvm = javaVirtualMachine
          sharedJVMPointer.classpath = classpath
          return javaVirtualMachine
        }
      }
    }
  }

  /// "Forget" the shared JavaVirtualMachine instance.
  ///
  /// This will allow the shared JavaVirtualMachine instance to be deallocated.
  public static func forgetShared() {
    debug("forget shared JVM, without destroying it")
    sharedJVM.withLock { sharedJVMPointer in
      sharedJVMPointer.jvm = nil
      sharedJVMPointer.classpath = []
    }
  }

  /// Parse JVM options from the SWIFT_JAVA_JVM_OPTIONS environment variable.
  /// 
  /// For example, to enable verbose JNI logging you can do: 
  /// ```
  /// export SWIFT_JAVA_JAVA_OPTS="-verbose:jni"
  /// ```
  public static func getSwiftJavaJVMEnvOptions() -> [String] {
    guard let optionsString = ProcessInfo.processInfo.environment["SWIFT_JAVA_JAVA_OPTS"],
          !optionsString.isEmpty else {
      return []
    }
    
    return optionsString
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}

extension JavaVirtualMachine {
  /// Describes the kinds of errors that can occur when interacting with JNI.
  enum VMError: Error {
    /// There is already a Java Virtual Machine.
    case existingVM

    /// JNI version mismatch error.
    case jniVersion

    /// Thread is detached from the VM.
    case threadDetached

    /// Out of memory.
    case outOfMemory

    /// Invalid arguments.
    case invalidArguments

    /// Unknown JNI error.
    case unknown(jint, file: String, line: UInt)

    init?(fromJNIError error: jint, file: String = #fileID, line: UInt = #line) {
      switch error {
      case JNI_OK: return nil
      case JNI_EDETACHED: self = .threadDetached
      case JNI_EVERSION: self = .jniVersion
      case JNI_ENOMEM: self = .outOfMemory
      case JNI_EEXIST: self = .existingVM
      case JNI_EINVAL: self = .invalidArguments
      default: self = .unknown(error, file: file, line: line)
      }
    }
  }

  enum JavaKitError: Error {
    case classpathEntryNotFound(entry: String, classpath: [String])
  }
}
