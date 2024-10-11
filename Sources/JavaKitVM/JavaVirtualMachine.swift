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
  public init(
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

    // Create the JVM.
    if JNI_CreateJavaVM(&jvm, &environment, &vmArgs) != JNI_OK {
      throw VMError.failedToCreateVM
    }

    self.jvm = jvm!
  }

  deinit {
    // Destroy the JVM.
    if jvm.pointee!.pointee.DestroyJavaVM(jvm) != JNI_OK {
      fatalError("Failed to destroy the JVM.")
    }
  }

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

extension JavaVirtualMachine {
  enum VMError: Error {
    case failedToCreateVM
    case failedToAttachThread
    case failedToDetachThread
  }
}
