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


extension Array: JavaValue where Element: JavaValue {
  public typealias JNIType = jobject?

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

  public static var javaType: JavaType { .array(Element.javaType) }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    let jniCount = environment.interface.GetArrayLength(environment, value)
    let jniArray: [Element.JNIType] =
      if let value {
        .init(
          unsafeUninitializedCapacity: Int(jniCount)
        ) { buffer, initializedCount in
          Element.jniGetArrayRegion(in: environment)(
            environment,
            value,
            0,
            jniCount,
            buffer.baseAddress
          )
          initializedCount = Int(jniCount)
        }
      } else {
        []
      }

    // FIXME: If we have a 1:1 match between the Java layout and the
    // Swift layout, as we do for integer/float types, we can do some
    // awful alias tricks above to have JNI fill in the contents of the
    // array directly without this extra copy. For now, just map.
    self = jniArray.map { Element(fromJNI: $0, in: environment) }
  }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
    // FIXME: If we have a 1:1 match between the Java layout and the
    // Swift layout, as we do for integer/float types, we can do some
    // awful alias tries to avoid creating the second array here.
    let jniArray = Element.jniNewArray(in: environment)(environment, Int32(count))!
    let jniElementBuffer: [Element.JNIType] = map {
      $0.getJNIValue(in: environment)
    }
    Element.jniSetArrayRegion(in: environment)(
      environment,
      jniArray,
      0,
      jsize(count),
      jniElementBuffer
    )
    return jniArray
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
      // FIXME: We should have a bridged JavaArray that we can use here.
      let arrayClass = environment.interface.FindClass(environment, "java/lang/Array")
      return environment.interface.NewObjectArray(environment, size, arrayClass, nil)
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
