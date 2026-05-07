//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJava

extension Dictionary: @retroactive JavaValue, JavaBoxable where Key: JavaBoxable & Hashable, Value: JavaBoxable {
  public typealias JNIType = jobject?

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

  public static var javaType: JavaType {
    JavaType(className: "org.swift.swiftkit.core.collections.SwiftDictionaryMap")
  }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
    toJavaObject(in: environment)
  }

  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let selfPointer = self.dictionaryGetJNIValue(in: environment)
    var args = [jvalue(), jvalue()]
    args[0].j = selfPointer
    args[1].l = JavaSwiftArena.defaultAutoArena.javaThis
    return environment.interface.CallStaticObjectMethodA(
      environment,
      _JNIMethodIDCache.SwiftDictionaryMap.class,
      _JNIMethodIDCache.SwiftDictionaryMap.wrapMemoryAddressUnsafe,
      &args
    )
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Self {
    guard let obj else {
      fatalError("Dictionary.fromJavaObject received a null Java object")
    }
    let selfPointer = environment.interface.CallLongMethodA(
      environment,
      obj,
      _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
      nil
    )
    return Self(fromJNI: selfPointer, in: environment)
  }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = Self.fromJavaObject(value, in: environment)
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
      environment.interface.NewObjectArray(
        environment,
        size,
        _JNIMethodIDCache.SwiftDictionaryMap.class,
        nil
      )
    }
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    { environment, array, start, length, outPointer in
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
    { environment, array, start, length, outPointer in
      let buffer = UnsafeBufferPointer(start: outPointer, count: Int(length))
      for i in start..<start + length {
        environment.interface.SetObjectArrayElement(environment, array, i, buffer[Int(i)])
      }
    }
  }

  public static var jniPlaceholderValue: JNIType { nil }
}

extension Set: @retroactive JavaValue, JavaBoxable where Element: JavaBoxable & Hashable {
  public typealias JNIType = jobject?

  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

  public static var javaType: JavaType {
    JavaType(className: "org.swift.swiftkit.core.collections.SwiftSet")
  }

  public func getJNIValue(in environment: JNIEnvironment) -> JNIType {
    toJavaObject(in: environment)
  }

  public func toJavaObject(in environment: JNIEnvironment) -> jobject? {
    let selfPointer = self.setGetJNIValue(in: environment)
    var args = [jvalue(), jvalue()]
    args[0].j = selfPointer
    args[1].l = JavaSwiftArena.defaultAutoArena.javaThis
    return environment.interface.CallStaticObjectMethodA(
      environment,
      _JNIMethodIDCache.SwiftSet.class,
      _JNIMethodIDCache.SwiftSet.wrapMemoryAddressUnsafe,
      &args
    )
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Self {
    guard let obj else {
      fatalError("Set.fromJavaObject received a null Java object")
    }
    let selfPointer = environment.interface.CallLongMethodA(
      environment,
      obj,
      _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
      nil
    )
    return Self(fromJNI: selfPointer, in: environment)
  }

  public init(fromJNI value: JNIType, in environment: JNIEnvironment) {
    self = Self.fromJavaObject(value, in: environment)
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
      environment.interface.NewObjectArray(
        environment,
        size,
        _JNIMethodIDCache.SwiftSet.class,
        nil
      )
    }
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    { environment, array, start, length, outPointer in
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
    { environment, array, start, length, outPointer in
      let buffer = UnsafeBufferPointer(start: outPointer, count: Int(length))
      for i in start..<start + length {
        environment.interface.SetObjectArrayElement(environment, array, i, buffer[Int(i)])
      }
    }
  }

  public static var jniPlaceholderValue: JNIType { nil }
}
