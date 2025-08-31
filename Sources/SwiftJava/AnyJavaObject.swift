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


/// Protocol that describes Swift types that are bridged to a Java class type.
///
/// This protocol provides operations common to the Swift projections of
/// Java classes. This includes the full Java class name including package
/// (e.g., `"java.util.Vector`) and the Swift projection of the superclass
/// (via the `Superclass` associated type).
///
/// One can access the superclass instance via the `super` property, perform
/// the equivalent of a Java `instanceof` check with the `is` method, or
/// attempt a dynamic cast via `as` method. For example:
///
/// ```swift
/// if let someObject.as(MyJavaType.self) { ... }
/// ```
///
/// Static methods on a `AnyJavaObject` type can be accessed via the `javaClass`
/// property, which produces a `JavaClass` instance specialized to this
/// type (i.e., `JavaClass<Self>`) and is the Swift equivalent to Java's
/// `Class` type.
///
/// Swift types rarely define the conformance to this protocol directly.
/// Instead, such a type will use the `@JavaClass` macro to state that it
/// is a projection of a Java class, and the macro will fill in both the
/// conformance and the operations needed to satisfy the protocol requirements.
public protocol AnyJavaObject {
  /// Retrieve the full Java class name (e.g., java.util.Vector)
  static var fullJavaClassName: String { get }

  /// Initialize a Java object from the Swift instance that keeps it alive.
  init(javaHolder: JavaObjectHolder)

  /// The Swift instance that keeps the Java holder alive.
  var javaHolder: JavaObjectHolder { get }
}

/// Protocol that allows Swift types to specify a custom Java class loader on
/// initialization. This is useful for platforms (e.g. Android) where the default
/// class loader does not make all application classes visible.
public protocol CustomJavaClassLoader: AnyJavaObject {
  static func getJavaClassLoader(in environment: JNIEnvironment) throws -> JavaClassLoader!
}

extension AnyJavaObject {
  /// Retrieve the underlying Java object.
  public var javaThis: jobject {
    javaHolder.object!
  }

  /// Retrieve the environment in which this Java object resides.
  public var javaEnvironment: JNIEnvironment {
    javaHolder.environment
  }

  /// The full Java class name, where each component is separated by a "/".
  static var fullJavaClassNameWithSlashes: String {
    let seq = fullJavaClassName.map { $0 == "." ? "/" as Character : $0 }
    return String(seq)
  }

  /// Initialize a Java object from its instance.
  public init(javaThis: jobject, environment: JNIEnvironment) {
    self.init(javaHolder: JavaObjectHolder(object: javaThis, environment: environment))
  }

  /// Retrieve the JNI class object for this type.
  var jniClass: jclass? {
    javaEnvironment.interface.GetObjectClass(javaEnvironment, javaThis)
  }

  /// Retrieve the Java class instance for this object.
  public var javaClass: JavaClass<Self> {
    JavaClass(javaThis: jniClass!, environment: javaEnvironment)
  }

  /// Retrieve the Java class for this type using the default class loader.
  private static func _withJNIClassFromDefaultClassLoader<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    let resolvedClass = try environment.translatingJNIExceptions {
      environment.interface.FindClass(
        environment,
        fullJavaClassNameWithSlashes
      )
    }!
    return try body(resolvedClass)
  }

  /// Retrieve the Java class for this type using a specific class loader.
  private static func _withJNIClassFromCustomClassLoader<Result>(
    _ classLoader: JavaClassLoader,
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    let resolvedClass = try classLoader.findClass(fullJavaClassName)
    return try body(resolvedClass!.javaThis)
  }

  /// Retrieve the Java class for this type and execute body().
  @_spi(Testing)
  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    if let customJavaClassLoader = self as? CustomJavaClassLoader.Type,
       let customClassLoader = try customJavaClassLoader.getJavaClassLoader(in: environment) {
      try _withJNIClassFromCustomClassLoader(customClassLoader, in: environment, body)
    } else {
      try _withJNIClassFromDefaultClassLoader(in: environment, body)
    }
  }
}
