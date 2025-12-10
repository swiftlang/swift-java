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

public final class JNI {
  public fileprivate(set) static var shared: JNI!

  public let applicationClassLoader: JavaClassLoader
  public let globalArena: JavaSwiftArena

  init(fromVM javaVM: JavaVirtualMachine) {
    let environment = try! javaVM.environment()

    self.applicationClassLoader = try! JavaClass<JavaThread>(environment: environment).currentThread().getContextClassLoader()

    // Find global arena
    let swiftMemoryClass = environment.interface.FindClass(environment, "org/swift/swiftkit/core/SwiftMemoryManagement")!
    let arenaFieldID = environment.interface.GetStaticFieldID(
        environment,
        swiftMemoryClass,
        "GLOBAL_SWIFT_JAVA_ARENA",
        "Lorg/swift/swiftkit/core/SwiftArena;"
    )
    let localObject = environment.interface.GetStaticObjectField(environment, swiftMemoryClass, arenaFieldID)!
    self.globalArena = JavaSwiftArena(javaThis: localObject, environment: environment)
    environment.interface.DeleteLocalRef(environment, localObject)
  }
}

// Called by generated code, and not automatically by Java.
public func _JNI_OnLoad(_ javaVM: JavaVMPointer, _ reserved: UnsafeMutableRawPointer) {
  JNI.shared = JNI(fromVM: JavaVirtualMachine(adoptingJVM: javaVM))
}
