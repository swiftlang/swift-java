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

import JavaKit

typealias JavaVMPointer = UnsafeMutablePointer<JavaVM?>

public final class JavaVirtualMachine: @unchecked Sendable {
  /// The JNI version that we depend on.
  static let jniVersion = JNI_VERSION_1_6

  /// The Java virtual machine instance.
  private let jvm: JavaVMPointer

  /// Whether to destroy the JVM on deinit.
  private let destroyOnDeinit: Bool

  /// Adopt an existing JVM pointer.
  private init(adoptingJVM jvm: JavaVMPointer) {
    self.jvm = jvm
    self.destroyOnDeinit = false
  }

  /// Initialize a new Java virtual machine instance.
  ///
  /// - Parameters:
  ///   - classPath: The directories, JAR files, and ZIP files in which the JVM
  ///     should look to find classes. This maps to the VM option
  ///     `-Djava.class.path=`.
  ///   - vmOptions: Options that should be passed along to the JVM, which will
  ///     be prefixed by the class-path argument described above.
  ///   - ignoreUnrecognized: Whether the JVM should ignore any VM options it
  ///     does not recognize.
  private init(
    classPath: [String] = [],
    vmOptions: [String] = [],
    ignoreUnrecognized: Bool = true
  ) throws {
    var jvm: JavaVMPointer? = nil
    var environment: UnsafeMutableRawPointer? = nil
    var vmArgs = JavaVMInitArgs()
    vmArgs.version = JavaVirtualMachine.jniVersion
    vmArgs.ignoreUnrecognized = jboolean(ignoreUnrecognized ? JNI_TRUE : JNI_FALSE)

    // Construct the complete list of VM options.
    var allVMOptions: [String] = []
    if !classPath.isEmpty {
      let colonSeparatedClassPath = classPath.joined(separator: ":")
      allVMOptions.append("-Djava.class.path=\(colonSeparatedClassPath)")
    }
    allVMOptions.append(contentsOf: vmOptions)

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

    // Create the JVM instance.
    let createResult = JNI_CreateJavaVM(&jvm, &environment, &vmArgs)
    if createResult != JNI_OK {
      if createResult == JNI_EEXIST {
        throw VMError.existingVM
      }

      throw VMError.failedToCreateVM
    }

    self.jvm = jvm!
    self.destroyOnDeinit = true
  }

  deinit {
    if destroyOnDeinit {
      // Destroy the JVM.
      if jvm.pointee!.pointee.DestroyJavaVM(jvm) != JNI_OK {
        fatalError("Failed to destroy the JVM.")
      }
    }
  }
}

// MARK: Java thread management.
extension JavaVirtualMachine {
  /// Produce the JNI environment for the active thread, attaching this
  /// thread to the JVM if it isn't already.
  ///
  /// - Parameter
  ///   - asDaemon: Whether this thread should be treated as a daemon
  ///     thread in the Java Virtual Machine.
  public func environment(asDaemon: Bool = false) throws -> JNIEnvironment {
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

    // Attach the current thread to the JVM.
    let attachResult: jint
    if asDaemon {
      attachResult = jvm.pointee!.pointee.AttachCurrentThreadAsDaemon(jvm, &environment, nil)
    } else {
      attachResult = jvm.pointee!.pointee.AttachCurrentThread(jvm, &environment, nil)
    }

    if attachResult == JNI_OK, let environment {
      return environment.assumingMemoryBound(to: JNIEnv?.self)
    }

    throw VMError.failedToAttachThread
  }

  /// Detach the current thread from the Java Virtual Machine. All Java
  /// threads waiting for this thread to die are notified.
  public func detachCurrentThread() throws {
    let result = jvm.pointee!.pointee.DetachCurrentThread(jvm)
    if result != JNI_OK {
      throw VMError.failedToDetachThread
    }
  }
}

// MARK: Shared Java Virtual Machine management.
extension JavaVirtualMachine {
  /// The globally shared JavaVirtualMachine instance, behind a lock.
  ///
  /// TODO: If the use of the lock itself ends up being slow, we could
  /// use an atomic here instead because our access pattern is fairly
  /// simple.
  private static let sharedJVM: LockedState<JavaVirtualMachine?> = .init(initialState: nil)

  /// Access the shared Java Virtual Machine instance.
  ///
  /// If there is no shared Java Virtual Machine, create one with the given
  /// arguments. Note that this function makes no attempt to try to augment
  /// an existing virtual machine instance with the options given, so it is
  /// up to clients to ensure that consistent arguments are provided to all
  /// calls.
  ///
  /// - Parameters:
  ///   - classPath: The directories, JAR files, and ZIP files in which the JVM
  ///     should look to find classes. This maps to the VM option
  ///     `-Djava.class.path=`.
  ///   - vmOptions: Options that should be passed along to the JVM, which will
  ///     be prefixed by the class-path argument described above.
  ///   - ignoreUnrecognized: Whether the JVM should ignore any VM options it
  ///     does not recognize.
  public static func shared(
    classPath: [String] = [],
    vmOptions: [String] = [],
    ignoreUnrecognized: Bool = true
  ) throws -> JavaVirtualMachine {
    try sharedJVM.withLock { (sharedJVMPointer: inout JavaVirtualMachine?) in
      // If we already have a JavaVirtualMachine instance, return it.
      if let existingInstance = sharedJVMPointer {
        return existingInstance
      }

      while true {
        var wasExistingVM: Bool = false
        while true {
          // Query the JVM itself to determine whether there is a JVM
          // instance that we don't yet know about.
          var jvm: UnsafeMutablePointer<JavaVM?>? = nil
          var numJVMs: jsize = 0
          if JNI_GetCreatedJavaVMs(&jvm, 1, &numJVMs) == JNI_OK, numJVMs >= 1 {
            // Adopt this JVM into a new instance of the JavaVirtualMachine
            // wrapper.
            let javaVirtualMachine = JavaVirtualMachine(adoptingJVM: jvm!)
            sharedJVMPointer = javaVirtualMachine
            return javaVirtualMachine
          }

          precondition(
            !wasExistingVM,
            "JVM reports that an instance of the JVM was already created, but we didn't see it."
          )

          // Create a new instance of the JVM.
          let javaVirtualMachine: JavaVirtualMachine
          do {
            javaVirtualMachine = try JavaVirtualMachine(
              classPath: classPath,
              vmOptions: vmOptions,
              ignoreUnrecognized: ignoreUnrecognized
            )
          } catch VMError.existingVM {
            // We raced with code outside of this JavaVirtualMachine instance
            // that created a VM while we were trying to do the same. Go
            // through the loop again to pick up the underlying JVM pointer.
            wasExistingVM = true
            continue
          }

          sharedJVMPointer = javaVirtualMachine
          return javaVirtualMachine
        }
      }
    }
  }
}

extension JavaVirtualMachine {
  enum VMError: Error {
    case failedToCreateVM
    case failedToAttachThread
    case failedToDetachThread
    case failedToQueryVM
    case existingVM
  }
}
