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

/// Attached macro that declares that a particular `struct` type is a wrapper around a Java class.
///
/// Use this macro to describe a type that was implemented as a class in Java. The
/// argument is the full class name with its package (e.g., `java.lang.Object`), with
/// an optional "extends" parameter to indicate which class it inherits.
///
/// The type itself should be a struct and should contain `@JavaMethod` and
/// `@JavaField` declarations that describe the Swift projection of each of
/// the methods, constructors, and fields that are implemented in the Java
/// class.
///
/// Usage:
///
/// ```swift
/// @JavaClass("org.swift.example.HelloSwift", extends: JavaString.self)
/// struct HelloSwift {
/// }
/// ```
@attached(
  member,
  names: named(fullJavaClassName),
  named(javaHolder),
  named(javaThis),
  named(javaEnvironment),
  named(init(javaHolder:)),
  named(JavaSuperclass)
)
@attached(extension, conformances: AnyJavaObject)
@attached(peer)
public macro JavaClass(
  _ fullClassName: String,
  extends: (any AnyJavaObject.Type)? = nil,
  implements: (any AnyJavaObject.Type)?...
) = #externalMacro(module: "JavaKitMacros", type: "JavaClassMacro")

/// Attached macro that declares that a particular `struct` type is a wrapper around a Java interface.
///
/// Use this macro to describe a type that was implemented as an
/// interface in Java. The argument is the full interface name with its package (e.g., `java.lang.reflect.Type`), with
/// an optional "extends" parameter to indicate which other
/// interfaces it extends (if any).
///
/// The type itself should be a struct and should contain `@JavaMethod` and
/// `@JavaField` declarations that describe the Swift projection of each of
/// the methods, constructors, and fields that are part of the Java
/// interface.
///
/// Usage:
///
/// ```swift
/// @JavaInterface("java.lang.reflect.GenericArrayType", extends: Type.self)
/// struct GenericArrayType<T> {
/// }
/// ```
@attached(
  member,
  names: named(fullJavaClassName),
  named(javaHolder),
  named(javaThis),
  named(javaEnvironment),
  named(init(javaHolder:)),
  named(JavaSuperclass)
)
@attached(extension, conformances: AnyJavaObject)
public macro JavaInterface(_ fullClassName: String, extends: (any AnyJavaObject.Type)?...) =
  #externalMacro(module: "JavaKitMacros", type: "JavaClassMacro")

/// Attached macro that turns a Swift property into one that accesses a Java field on the underlying Java object.
///
/// The macro must be used within either a AnyJavaObject-conforming type or a specific JavaClass instance.
///
/// ```swift
/// @JavaClass("org.swift.example.HelloSwift")
/// struct HelloSwift {
///     @JavaField
///     var counter: Int32
/// }
/// ```
@attached(accessor)
public macro JavaField(_ javaFieldName: String? = nil) = #externalMacro(module: "JavaKitMacros", type: "JavaFieldMacro")

/// Attached macro that turns a Swift method into one that wraps a Java method on the underlying Java object.
///
/// The macro must be used within either a AnyJavaObject-conforming type or a specific JavaClass instance.
///
/// ```swift
/// @JavaMethod
/// func sayHelloBack(_ i: Int32) -> Double
/// ```
///
/// Initializers that use `@JavaMethod` need to have an `environment` parameter
/// of type `JNIEnvironment`, and the new underlying Java object will be created
/// within that environment. For example, the following initializer
///
/// ```swift
/// @JavaMethod
/// init(name: String, environment: JNIEnvironment)
/// ```
///
/// corresponds to the Java constructor `HelloSwift(String name)`.
@attached(body)
public macro JavaMethod() = #externalMacro(module: "JavaKitMacros", type: "JavaMethodMacro")

/// Macro that exposes the given Swift method as a native method in Java.
///
/// The macro must be used within a struct type marked with `@JavaClass`, and there
/// must be a corresponding Java method declared as `native` for it to be called from
/// Java. For example, given this Swift method:
///
/// ```swift
/// @ImplementsJava
/// func sayHello(i: Int32, _ j: Int32) -> Int32 {
///   // swift implementation
/// }
///
/// inside a struct with `@JavaClass("com.example.swift.HelloSwift")`, the
/// corresponding `HelloSwift` Java class should have:
///
/// ```java
/// public native int sayHello(int i, int j);
/// ```
@attached(peer)
public macro ImplementsJava() = #externalMacro(module: "JavaKitMacros", type: "ImplementsJavaMacro")
