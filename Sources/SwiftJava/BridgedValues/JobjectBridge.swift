//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// A strategy object that knows how to bridge a Swift type to and from Java.
///
/// Unlike `JavaBoxable`, this is not attached to the bridged nominal type itself,
/// which avoids protocol-conformance conflicts for inheritable classes.
public protocol JobjectBridge {
  associatedtype SwiftType

  /// Convert a Swift value to a Java object.
  static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject?

  /// Convert a Java object back to a Swift value.
  static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> SwiftType

  static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result
}

extension JobjectBridge {
  public static func isJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Bool {
    guard let obj else { return false }
    return (try? withJNIClass(in: environment) { cls in
      environment.interface.IsInstanceOf(environment, obj, cls) == JNI_TRUE
    }) ?? false
  }
}

public enum JavaBoxableBridge<T: JavaBoxable>: JobjectBridge {
  public typealias SwiftType = T

  public static func toJavaObject(_ value: T, in environment: JNIEnvironment) -> jobject? {
    value.toJavaObject(in: environment)
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> T {
    T.fromJavaObject(obj, in: environment)
  }

  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    try body(T.javaBoxClass)
  }
}

public enum JavaObjectBridge<T: AnyJavaObject>: JobjectBridge {
  public typealias SwiftType = T

  public static func toJavaObject(_ value: T, in environment: JNIEnvironment) -> jobject? {
    value.javaThis
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> T {
    guard let obj else {
      fatalError("\(T.self).fromJavaObject received a null Java object")
    }
    return T(javaThis: obj, environment: environment)
  }

  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    try T.withJNIClass(in: environment, body)
  }
}
