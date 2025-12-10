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

/// A type that represents the shared JNI environment
/// used to share any global JNI variables.
///
/// This is initialized when the `JNI_OnLoad` is triggered,
/// which happens when you call `System.loadLibrary(...)`
/// from Java.
public final class JNI {
  /// The shared JNI object, initialized by `JNI_OnLoad`
  public fileprivate(set) static var shared: JNI!

  /// The default application class loader
  public let applicationClassLoader: JavaClassLoader

  /// The default auto arena of SwiftKitCore
  public let defaultAutoArena: JavaSwiftArena

  init(fromVM javaVM: JavaVirtualMachine) {
    let environment = try! javaVM.environment()

    self.applicationClassLoader = try! JavaClass<JavaThread>(environment: environment).currentThread().getContextClassLoader()

    // Find global arena
    let swiftMemoryClass = environment.interface.FindClass(environment, "org/swift/swiftkit/core/SwiftMemoryManagement")!
    let arenaFieldID = environment.interface.GetStaticFieldID(
        environment,
        swiftMemoryClass,
        "DEFAULT_SWIFT_JAVA_AUTO_ARENA",
        JavaSwiftArena.mangledName
    )
    let localObject = environment.interface.GetStaticObjectField(environment, swiftMemoryClass, arenaFieldID)!
    self.defaultAutoArena = JavaSwiftArena(javaThis: localObject, environment: environment)
    environment.interface.DeleteLocalRef(environment, localObject)
  }
}

// Called by generated code, and not automatically by Java.
public func _JNI_OnLoad(_ javaVM: JavaVMPointer, _ reserved: UnsafeMutableRawPointer) {
  JNI.shared = JNI(fromVM: JavaVirtualMachine(adoptingJVM: javaVM))
}
