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
  named(init(javaHolder:)),
  named(JavaSuperclass),
  named(`as`)
)
@attached(extension, conformances: AnyJavaObject)
public macro JavaClass(
  _ fullClassName: String,
  extends: (any AnyJavaObject.Type)? = nil,
  implements: (any AnyJavaObject.Type)?...
) = #externalMacro(module: "SwiftJavaMacros", type: "JavaClassMacro")

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
  named(init(javaHolder:)),
  named(JavaSuperclass),
  named(`as`)
)
@attached(extension, conformances: AnyJavaObject)
public macro JavaInterface(_ fullClassName: String, extends: (any AnyJavaObject.Type)?...) =
  #externalMacro(module: "SwiftJavaMacros", type: "JavaClassMacro")

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
public macro JavaField(_ javaFieldName: String? = nil, isFinal: Bool = false) =
  #externalMacro(module: "SwiftJavaMacros", type: "JavaFieldMacro")

/// Attached macro that turns a Swift property into one that accesses a Java static field on the underlying Java object.
///
/// The macro must be used within a specific JavaClass instance.
///
/// ```swift
/// extension JavaClass<HelloSwift> {
///   @JavaStaticField
///   var initialValue: Double
/// }
/// ```
@attached(accessor)
public macro JavaStaticField(_ javaFieldName: String? = nil, isFinal: Bool = false) =
  #externalMacro(module: "SwiftJavaMacros", type: "JavaFieldMacro")

/// Attached macro that turns a Swift method into one that wraps a Java method on the underlying Java object.
///
/// The macro must be used in an AnyJavaObject-conforming type.
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
///
/// ### Generics and type-erasure
/// Swift and Java differ in how they represent generics at runtime.
/// In Java, generics are type-erased and the JVM representation of generic types is erased to `java.lang.Object`.
/// Swift on the other hand, reifies types which means a `Test<T>` in practice will be a specific type with
/// the generic substituted `Test<String>`. This means that at runtime, calling a generic @JavaMethod needs to know
/// which of the parameters (or result type) must be subjected to type-erasure as we form the call into the Java function.
///
/// In order to mark a generic return type you must indicate it to the @JavaMethod macro like this:
/// ```swift
/// // Java: class Test<T> { public <T> get(); }
/// @JavaMethod(typeErasedResult: "T!")
/// func get() -> T!
/// ```
/// This allows the macro to form a call into the get() method, which at runtime, will have an `java.lang.Object`
/// returning method signature, and then, convert the result to the expected `T` type on the Swift side.
@attached(body)
public macro JavaMethod(
  _ javaMethodName: String? = nil,
  typeErasedResult: String? = nil
) = #externalMacro(module: "SwiftJavaMacros", type: "JavaMethodMacro")

/// Attached macro that turns a Swift method on JavaClass into one that wraps
/// a Java static method on the underlying Java class object.
///
/// The macro must be used within a specific JavaClass instance.
///
/// ```swift
/// @JavaStaticMethod
/// func sayHelloBack(_ i: Int32) -> Double
/// ```
@attached(body)
public macro JavaStaticMethod(_ javaMethodName: String? = nil) =
  #externalMacro(module: "SwiftJavaMacros", type: "JavaMethodMacro")

/// Macro that marks extensions to specify that all of the @JavaMethod
/// methods are implementations of Java methods spelled as `native`.
///
/// For example, given a Java native method such as the following in
/// a Java class `org.swift.example.Hello`:
///
/// ```java
/// public native int sayHello(int i, int j);
/// ```
///
/// Assuming that the Java class with imported into Swift as `Hello`, t
/// the method can be implemented in Swift with the following:
///
/// ```swift
/// @JavaImplementation
/// extension Hello {
///   @JavaMethod
///   func sayHello(i: Int32, _ j: Int32) -> Int32 {
///     // swift implementation
///   }
/// }
/// ```
@attached(peer)
public macro JavaImplementation(_ fullClassName: String) =
  #externalMacro(module: "SwiftJavaMacros", type: "JavaImplementationMacro")
