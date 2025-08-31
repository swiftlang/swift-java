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


extension Float: JavaValue {
  public typealias JNIType = jfloat

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.f }

  public static var javaType: JavaType { .float }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallFloatMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetFloatField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetFloatField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticFloatMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticFloatField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticFloatField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewFloatArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetFloatArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetFloatArrayRegion
  }

  public static var jniPlaceholderValue: jfloat {
    0
  }
}

extension Double: JavaValue {
  public typealias JNIType = jdouble

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.d }

  public static var javaType: JavaType { .double }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallDoubleMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetDoubleField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetDoubleField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticDoubleMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticDoubleField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticDoubleField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewDoubleArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetDoubleArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetDoubleArrayRegion
  }

  public static var jniPlaceholderValue: jdouble {
    0
  }
}
