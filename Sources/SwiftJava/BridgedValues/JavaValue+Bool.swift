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


extension Bool: JavaValue {
  public typealias JNIType = jboolean

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.z }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType { self ? 1 : 0 }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = value != 0
  }

  public static var javaType: JavaType { .boolean }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallBooleanMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetBooleanField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetBooleanField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticBooleanMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticBooleanField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticBooleanField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    environment.interface.NewBooleanArray
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    environment.interface.GetBooleanArrayRegion
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    environment.interface.SetBooleanArrayRegion
  }

  public static var jniPlaceholderValue: jboolean {
    0
  }
}
