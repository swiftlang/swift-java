//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CSwiftJavaJNI

/// A type that represents the shared JNI environment
/// used to share any global JNI variables.
///
/// This is initialized when the `JNI_OnLoad` is triggered,
/// which happens when you call `System.loadLibrary(...)`
/// from Java.
package final class JNI {
  /// The shared JNI object, initialized by `JNI_OnLoad`
  ///
  /// This may be `nil` in the case where `SwiftJava` is not loaded as a dynamic lib
  /// by the Java sources.
  package fileprivate(set) static var shared: JNI?

  /// The default application class loader
  package let applicationClassLoader: JavaClassLoader?

  init(fromVM javaVM: JavaVirtualMachine) {
    // Update the global JavaVM
    JavaVirtualMachine.sharedJVM.withLock {
      $0 = javaVM
    }
    let environment = try! javaVM.environment()
    do {
      let clazz = try JavaClass<JavaThread>(environment: environment)
      guard let thread: JavaThread = clazz.currentThread() else {
        applicationClassLoader = nil
        return 
      }
      guard let cl = thread.getContextClassLoader() else {
        applicationClassLoader = nil
        return 
      }
      self.applicationClassLoader = cl
    } catch {
      fatalError("Failed to get current thread's ContextClassLoader: \(error)")
    }
  }
}

@_cdecl("JNI_OnLoad")
public func SwiftJava_JNI_OnLoad(javaVM: JavaVMPointer, reserved: UnsafeMutableRawPointer) -> jint {
  JNI.shared = JNI(fromVM: JavaVirtualMachine(adoptingJVM: javaVM))
  return JNI_VERSION_1_6
}
