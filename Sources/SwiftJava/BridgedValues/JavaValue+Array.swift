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

extension Array: JavaValue where Element: JavaValue {
  public typealias JNIType = jobject?

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

  public static var javaType: JavaType { .array(Element.javaType) }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    let jniCount = environment.interface.GetArrayLength(environment, value)
    let count = Int(jniCount)

    guard let value else {
      self = []
      return
    }

    // Fast path for byte types: Since the memory layout of `jbyte` (Int8) and UInt8/Int8 is identical,
    // we can rebind the memory and fill it directly without creating an intermediate array.
    // This mirrors the optimization in `getJNIValue` in the reverse direction.
    if Element.self == UInt8.self {
      let result = [UInt8](unsafeUninitializedCapacity: count) { buffer, initializedCount in
        buffer.withMemoryRebound(to: jbyte.self) { jbyteBuffer in
          UInt8.jniGetArrayRegion(in: environment)(
            environment,
            value,
            0,
            jniCount,
            jbyteBuffer.baseAddress
          )
        }
        initializedCount = count
      }
      self = result as! Self
    } else if Element.self == Int8.self {
      let result = [Int8](unsafeUninitializedCapacity: Int(jniCount)) { buffer, initializedCount in
        Int8.jniGetArrayRegion(in: environment)(
          environment,
          value,
          0,
          jniCount,
          buffer.baseAddress
        )
        initializedCount = count
      }
      self = result as! Self
    } else {
      // Slow path for other types: create intermediate array and map
      let jniArray = [Element.JNIType](unsafeUninitializedCapacity: count) { buffer, initializedCount in
        Element.jniGetArrayRegion(in: environment)(
          environment,
          value,
          0,
          jniCount,
          buffer.baseAddress
        )
        initializedCount = Int(jniCount)
      }
      self = jniArray.map { Element(fromJNI: $0, in: environment) }
    }
  }

  @inlinable
  public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
    let count = self.count
    var jniArray = Element.jniNewArray(in: environment)(environment, Int32(count))!

    if Element.self == UInt8.self || Element.self == Int8.self {
      // Fast path, Since the memory layout of `jbyte`` and those is the same, we rebind the memory
      // rather than convert every element independently. This allows us to avoid another Swift array creation.
      self.withUnsafeBytes { buffer in
        buffer.getJNIValue(into: &jniArray, in: environment)
      }
    } else {
      // Slow path, convert every element to the apropriate JNIType:
      let jniElementBuffer: [Element.JNIType] = self.map { // meh, temporary array
        $0.getJNIValue(in: environment)
      }
      Element.jniSetArrayRegion(in: environment)(
        environment,
        jniArray,
        0,
        jsize(self.count),
        jniElementBuffer
      )
    }

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
    { environment, size in
      // FIXME: We should have a bridged JavaArray that we can use here.
      let arrayClass = environment.interface.FindClass(environment, "java/lang/Array")
      return environment.interface.NewObjectArray(environment, size, arrayClass, nil)
    }
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    { environment, array, start, length, outPointer in
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
    { environment, array, start, length, outPointer in
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
