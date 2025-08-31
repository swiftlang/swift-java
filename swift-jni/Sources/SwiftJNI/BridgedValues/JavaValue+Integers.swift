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


extension UInt8: JavaValue {
  public typealias JNIType = jbyte

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.b }

  public static var javaType: JavaType { .byte }

  /// Retrieve the JNI value.
  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { JNIType(self) }

  /// Initialize from a JNI value.
  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = Self(value)
  }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallByteMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetByteField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetByteField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticByteMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticByteField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticByteField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewByteArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetByteArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetByteArrayRegion
  }

  public static var jniPlaceholderValue: jbyte {
    0
  }
}

extension Int8: JavaValue {
  public typealias JNIType = jbyte

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.b }

  public static var javaType: JavaType { .byte }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallByteMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetByteField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetByteField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticByteMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticByteField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticByteField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewByteArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetByteArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetByteArrayRegion
  }

  public static var jniPlaceholderValue: jbyte {
    0
  }
}

extension UInt16: JavaValue {
  public typealias JNIType = jchar

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.c }

  public static var javaType: JavaType { .char }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallCharMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetCharField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetCharField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticCharMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticCharField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticCharField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewCharArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetCharArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetCharArrayRegion
  }

  public static var jniPlaceholderValue: jchar {
    0
  }
}

extension Int16: JavaValue {
  public typealias JNIType = jshort

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.s }

  public static var javaType: JavaType { .short }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallShortMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetShortField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetShortField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticShortMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticShortField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticShortField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewShortArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetShortArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetShortArrayRegion
  }

  public static var jniPlaceholderValue: jshort {
    0
  }
}

extension UInt32: JavaValue {
  public typealias JNIType = jint

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.i }

  public static var javaType: JavaType { .int }

  /// Retrieve the JNI value.
  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { JNIType(self) }

  /// Initialize from a JNI value.
  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = Self(value)
  }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallIntMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetIntField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetIntField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticIntMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticIntField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticIntField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewIntArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetIntArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetIntArrayRegion
  }

  public static var jniPlaceholderValue: jint {
    0
  }
}

extension Int32: JavaValue {
  public typealias JNIType = jint

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.i }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { JNIType(self) }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = Int32(value)
  }

  public static var javaType: JavaType { .int }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallIntMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetIntField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetIntField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticIntMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticIntField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticIntField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewIntArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetIntArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetIntArrayRegion
  }

  public static var jniPlaceholderValue: jint {
    0
  }
}

extension UInt64: JavaValue {
  public typealias JNIType = jlong

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.j }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { JNIType(self) }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = UInt64(value)
  }

  public static var javaType: JavaType { .long }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallLongMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetLongField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetLongField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticLongMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticLongField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticLongField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewLongArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetLongArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetLongArrayRegion
  }

  public static var jniPlaceholderValue: jlong {
    0
  }
}

extension Int64: JavaValue {
  public typealias JNIType = jlong

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.j }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { JNIType(self) }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = Int64(value)
  }

  public static var javaType: JavaType { .long }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallLongMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetLongField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetLongField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticLongMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticLongField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticLongField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewLongArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetLongArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetLongArrayRegion
  }

  public static var jniPlaceholderValue: jlong {
    0
  }
}

#if _pointerBitWidth(_32)
extension Int: JavaValue {

  public typealias JNIType = jint

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.i }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { JNIType(self) }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = Int(value)
  }

  public static var javaType: JavaType { .int }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallIntMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetIntField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetIntField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticIntMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticIntField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticIntField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewIntArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetIntArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetIntArrayRegion
  }

  public static var jniPlaceholderValue: jint {
    0
  }
}
#elseif _pointerBitWidth(_64)
extension Int: JavaValue {
  public typealias JNIType = jlong

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.j }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { JNIType(self) }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = Int(value)
  }

  public static var javaType: JavaType { .long }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallLongMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetLongField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetLongField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticLongMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticLongField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticLongField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewLongArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetLongArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetLongArrayRegion
  }

  public static var jniPlaceholderValue: jlong {
    0
  }
}
#endif
