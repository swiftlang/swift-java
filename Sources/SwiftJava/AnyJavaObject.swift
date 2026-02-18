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

import CSwiftJavaJNI

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
public protocol AnyJavaObjectWithCustomClassLoader: AnyJavaObject {
  static func getJavaClassLoader(in environment: JNIEnvironment) throws -> JavaClassLoader!
}

extension AnyJavaObject {
  /// Retrieve the underlying Java object.
  public var javaThis: jobject {
    javaHolder.object! // FIXME: this is a bad idea, can be null
  }

  public var javaThisOptional: jobject? {
    javaHolder.object
  }

  /// Retrieve the environment in which this Java object was created.
  public var javaEnvironment: JNIEnvironment {
    javaHolder.environment
  }

  /// The full Java class name, where each component is separated by a "/".
  static var fullJavaClassNameWithSlashes: String {
    let seq = fullJavaClassName.map { $0 == "." ? "/" as Character : $0 }
    return String(seq)
  }

  /// The mangled name for this java class
  public static var mangledName: String {
    "L\(fullJavaClassNameWithSlashes);"
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
    do {
      let resolvedClass = try environment.translatingJNIExceptions {
        environment.interface.FindClass(
          environment,
          fullJavaClassNameWithSlashes
        )
      }!
      return try body(resolvedClass)
    } catch {
      // If we are in a Java environment where we have loaded
      // SwiftJava dynamically, we have access to the application class loader
      // so lets try that as as a fallback
      if let applicationClassLoader = JNI.shared?.applicationClassLoader {
        return try _withJNIClassFromCustomClassLoader(
          applicationClassLoader,
          in: environment
        ) { applicationLoadedClass in
          try body(applicationLoadedClass)
        }
      } else {
        throw error
      }
    }
  }

  /// Retrieve the Java class for this type using a specific class loader.
  private static func _withJNIClassFromCustomClassLoader<Result>(
    _ classLoader: JavaClassLoader,
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    let resolvedClass = try classLoader.findClass(fullJavaClassName)
    // OK to force unwrap, as classLoader will throw ClassNotFoundException
    // if the class cannot be found.
    return try body(resolvedClass!.javaThis)
  }

  /// Retrieve the Java class for this type and execute body().
  @_spi(Testing)
  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    if let AnyJavaObjectWithCustomClassLoader = self as? AnyJavaObjectWithCustomClassLoader.Type,
      let customClassLoader = try AnyJavaObjectWithCustomClassLoader.getJavaClassLoader(in: environment)
    {
      do {
        return try _withJNIClassFromCustomClassLoader(customClassLoader, in: environment) { clazz in
          try body(clazz)
        }
      } catch {
        return try _withJNIClassFromDefaultClassLoader(in: environment, body)
      }
    } else {
      return try _withJNIClassFromDefaultClassLoader(in: environment, body)
    }
  }
}
