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


extension Optional: JavaValue where Wrapped: AnyJavaObject {
  public typealias JNIType = jobject?

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
    switch self {
    case let value?: value.javaThis
    case nil: nil
    }
  }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    if let this = value {
      // FIXME: Think about checking the runtime type?
      self = Wrapped(javaThis: this, environment: environment)
    } else {
      self = nil
    }
  }

  public static var javaType: JavaType {
    JavaType(className: Wrapped.fullJavaClassName)
  }

  public static func jniMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallObjectMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetObjectField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetObjectField
  }

  public static func jniStaticMethodCall(
    in environment: JNIEnvironment
  ) -> ((JNIEnvironment, jobject, jmethodID, UnsafePointer<jvalue>?) -> JNIType) {
    environment.interface.CallStaticObjectMethodA
  }

  public static func jniStaticFieldGet(in environment: JNIEnvironment) -> JNIStaticFieldGet<JNIType> {
    environment.interface.GetStaticObjectField
  }

  public static func jniStaticFieldSet(in environment: JNIEnvironment) -> JNIStaticFieldSet<JNIType> {
    environment.interface.SetStaticObjectField
  }

  public static func jniNewArray(in environment: JNIEnvironment) -> JNINewArray {
    return { environment, size in
      try! Wrapped.withJNIClass(in: environment) { jniClass in
        environment.interface.NewObjectArray(environment, size, jniClass, nil)
      }
    }
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    return { environment, array, start, length, outPointer in
      let buffer = UnsafeMutableBufferPointer(start: outPointer, count: Int(length))
      for i in start..<start + length {
        buffer.initializeElement(
          at: Int(i),
          to: environment.interface.GetObjectArrayElement(environment, array, Int32(i))
        )
      }
    }
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    return { environment, array, start, length, outPointer in
      let buffer = UnsafeBufferPointer(start: outPointer, count: Int(length))
      for i in start..<start + length {
        environment.interface.SetObjectArrayElement(environment, array, i, buffer[Int(i)])
      }
    }
  }

  public static var jniPlaceholderValue: jobject? {
    nil
  }
}
