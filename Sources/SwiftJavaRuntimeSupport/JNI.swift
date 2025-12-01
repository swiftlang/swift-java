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

import SwiftJava
import CSwiftJavaJNI

final class JNI {
  static var shared: JNI!

  let applicationClassLoader: JavaClassLoader

  init(fromVM javaVM: JavaVirtualMachine) {
    self.applicationClassLoader = try! JavaClass<JavaThread>(environment: javaVM.environment()).currentThread().getContextClassLoader()
  }
}

// Called by generated code, and not automatically by Java.
public func _JNI_OnLoad(_ javaVM: JavaVMPointer, _ reserved: UnsafeMutableRawPointer) {
  JNI.shared = JNI(fromVM: JavaVirtualMachine(adoptingJVM: javaVM))
}
