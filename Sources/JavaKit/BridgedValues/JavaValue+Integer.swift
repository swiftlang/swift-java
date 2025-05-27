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

import JavaTypes

// TODO: extension JavaValue: CustomStringConvertible where JNIType == jobject? {
extension JavaInteger: CustomStringConvertible {
    public var description: String {
        "JavaKit.\(Self.self)(\(toString()))"
    }
}

extension JavaInteger: JavaValue {
  public typealias JNIType = jobject?

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

  public static var javaType: JavaType {
    .class(package: "java.lang", name: "Integer")
  }

  // FIXME: cannot implement in extension, need to fix source generator
//  public required init(fromJNI value: JNIType, in environment: JNIEnvironment) {
//    fatalError()
//  }


  public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
    fatalError()
  }

  public static func jniMethodCall(in environment: JNIEnvironment) -> JNIMethodCall<JNIType> {
    environment.interface.CallObjectMethodA
  }

  public static func jniFieldGet(in environment: JNIEnvironment) -> JNIFieldGet<JNIType> {
    environment.interface.GetObjectField
  }

  public static func jniFieldSet(in environment: JNIEnvironment) -> JNIFieldSet<JNIType> {
    environment.interface.SetObjectField
  }

  public static func jniStaticMethodCall(in environment: JNIEnvironment) -> JNIStaticMethodCall<JNIType> {
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
      // FIXME: Introduce a JavaString class that we can use for this.
      let clazz = environment.interface.FindClass(environment, "java/lang/Integer")
      return environment.interface.NewObjectArray(environment, size, clazz, nil)
    }
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    return { environment, array, start, length, outPointer in
      let buffer = UnsafeMutableBufferPointer(start: outPointer, count: Int(length))
      for i in 0..<length {
        buffer.initializeElement(
          at: Int(i),
          to: environment.interface.GetObjectArrayElement(environment, array, Int32(start + i))
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
