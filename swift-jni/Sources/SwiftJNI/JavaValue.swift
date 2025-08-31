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

/// Describes a type that can be bridged with Java.
///
/// `JavaValue` is the base protocol for bridging between Swift types and their
/// Java counterparts via the Java Native Interface (JNI). `JavaValue` is suitable
/// for describing both value types (such as `Int32` or `Bool`) and object types.
/// The Swift type conforms to `JavaValue`, and its `JNIType` associated type
/// provides the corresponding JNI type (e.g., `jint`, `jboolean`). Java classes
/// expressed in Swift also conform to the `JavaValue` protocol through the
/// `AnyJavaObject` protocol, as do Swift's `String` (bridged from
/// `java.lang.String`) and `Array` (bridged from `java.lang.Array`).
///
/// Generally, clients will not explicitly make types conform to `JavaValue`,
/// nor use its operations directly. Instead, the `@JavaClass` macro should be
/// used to expose a Swift type for a Java class, and the macro will take care
/// of all of the details of conforming to `AnyJavaObject`.
///
/// The protocol provides operations to bridge values in both directions:
/// - `getJNIValue(in:)`: produces the JNI value (of type `JNIType`) for the
///   `self` Swift value in the given JNI environment.
/// - `init(fromJNI:in:)`: initializes a Swift value from the JNI value (of
///   type `JNIType`) in the given JNI environment.
///
/// The protocol also provides hooks to tie into JNI, including operations to
/// call Java methods that return an instance of this type (`jniMethodCall` and
/// `jniStaticMethodCall`), read/write Java fields of this type (`jniFieldGet`,
/// `jniFieldSet`, and the static versions thereof), and manage Java arrays
/// whose element type is the conforming Swift type (`jniNewArray`,
/// `jniGetArrayRegion`, `jniSetArrayRegion`).
public protocol JavaValue: ~Copyable {
  /// The JNI type that underlies this Java value.
  associatedtype JNIType

  /// Retrieve the JNI value.
  func getJNIValue(in environment: JNIEnvironment) -> JNIType

  /// Initialize from a JNI value.
  init(fromJNI value: JNIType, in environment: JNIEnvironment)

  /// The key path used to access the appropriate member of jvalue.
  static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { get }

  /// The Java type this describes.
  static var javaType: JavaType { get }

  /// The JNI function that performs a call to a method returning this type.
  static func jniMethodCall(in environment: JNIEnvironment) -> JNIMethodCall<JNIType>

  /// The JNI function to get the value of a field of this type.
  static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType>

  /// The JNI function to set the value of a field of this type.
  static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType>

  /// The JNI function that performs a call to a static method returning this type.
  static func jniStaticMethodCall(in environment: JNIEnvironment) -> JNIStaticMethodCall<JNIType>

  /// The JNI function to get the value of a static field of this type.
  static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType>

  /// The JNI function to set the value of a static field of this type.
  static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType>

  /// The JNI function to create a new array of this type.
  static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray

  /// The JNI function to get a region of an array.
  static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType>

  /// The JNI function to set a region of an array.
  static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType>

  /// The placeholder value used when we need a JNI value that will not
  /// actually be used. For example, this is used for a return back to JNI
  /// after we have thrown a Java exception.
  static var jniPlaceholderValue: JNIType { get }
}

/// The JNI environment.
public typealias JNIEnvironment = UnsafeMutablePointer<JNIEnv?>

/// Type of an operation that performs a JNI method call.
public typealias JNIMethodCall<Result> = (JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> Result

/// Type of an operation that gets a field's value via JNI.
public typealias JNIFieldGet<FieldType> = (JNIEnvironment, jobject, jfieldID) -> FieldType

/// Type of an operation that sets a field's value via JNI.
public typealias JNIFieldSet<FieldType> = (JNIEnvironment, jobject, jfieldID, FieldType) -> Void

/// Type of an operation that performs a JNI static method call.
public typealias JNIStaticMethodCall<Result> = (JNIEnvironment, jclass, jmethodID, UnsafePointer<jvalue>?) -> Result

/// Type of an operation that gets a static field's value via JNI.
public typealias JNIStaticFieldGet<FieldType> = (JNIEnvironment, jclass, jfieldID) -> FieldType

/// Type of an operation that sets a static field's value via JNI.
public typealias JNIStaticFieldSet<FieldType> = (JNIEnvironment, jclass, jfieldID, FieldType) -> Void

/// The type of an operation that produces a new Java array of type ArrayType
/// via JNI.
public typealias JNINewArray = (JNIEnvironment, jsize) -> jobject?

/// The type of an operation that fills in a buffer with elements in an
/// array via JNI.
public typealias JNIGetArrayRegion<ElementType> = (
  JNIEnvironment, jobject, jsize, jsize, UnsafeMutablePointer<ElementType>?
)
  -> Void

/// The type of an operation that fills in a Java array with elements from
/// a buffer.
/// array via JNI.
public typealias JNISetArrayRegion<ElementType> = (JNIEnvironment, jobject, jsize, jsize, UnsafePointer<ElementType>?)
  -> Void

extension JavaValue where Self: ~Copyable {
  /// Helper function to let us set a JNI type via keypath subscripting.
  private static func assignJNIType(_ cell: inout JNIType, to newValue: JNIType) {
    cell = newValue
  }

  /// Convert to a jvalue within the given JNI environment.
  public consuming func getJValue(in environment: JNIEnvironment) -> jvalue {
    var result = jvalue()
    Self.assignJNIType(&result[keyPath: Self.jvalueKeyPath], to: getJNIValue(in: environment))
    return result
  }

  /// Initialize from a jvalue
  init(fromJava value: jvalue, in environment: JNIEnvironment) {
    self.init(fromJNI: value[keyPath: Self.jvalueKeyPath], in: environment)
  }
}

// Default implementations when the JNI type and the Swift type line up.
extension JavaValue where Self.JNIType == Self {
  /// Retrieve the JNI value.
  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { self }

  /// Initialize from a JNI value.
  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = value
  }
}

extension JavaValue where Self: ~Copyable {
  /// The mangling string for this particular value.
  public static var jniMangling: String { javaType.mangledName }
}
