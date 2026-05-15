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

public enum DictionaryBridge<KeyBridge: JobjectBridge, ValueBridge: JobjectBridge>: JobjectBridge where KeyBridge.SwiftType: Hashable {
  public typealias SwiftType = [KeyBridge.SwiftType: ValueBridge.SwiftType]

  public static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject? {
    let selfPointer = value.dictionaryGetJNIValue(in: environment, keyBridge: KeyBridge.self, valueBridge: ValueBridge.self)
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

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> SwiftType {
    guard let obj else {
      fatalError("Dictionary.fromJavaObject received a null Java object")
    }
    let selfPointer = environment.interface.CallLongMethodA(
      environment,
      obj,
      _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
      nil
    )
    return SwiftType(fromJNI: selfPointer, in: environment, keyBridge: KeyBridge.self, valueBridge: ValueBridge.self)
  }

  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    try body(_JNIMethodIDCache.SwiftDictionaryMap.class)
  }
}

public enum SetBridge<ElementBridge: JobjectBridge>: JobjectBridge where ElementBridge.SwiftType: Hashable {
  public typealias SwiftType = Set<ElementBridge.SwiftType>

  public static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject? {
    let selfPointer = value.setGetJNIValue(in: environment, elementBridge: ElementBridge.self)
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

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> SwiftType {
    guard let obj else {
      fatalError("Set.fromJavaObject received a null Java object")
    }
    let selfPointer = environment.interface.CallLongMethodA(
      environment,
      obj,
      _JNIMethodIDCache.JNISwiftInstance.memoryAddress,
      nil
    )
    return SwiftType(fromJNI: selfPointer, in: environment, elementBridge: ElementBridge.self)
  }

  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    try body(_JNIMethodIDCache.SwiftSet.class)
  }
}

public enum OptionalBridge<WrappedBridge: JobjectBridge>: JobjectBridge {
  public typealias SwiftType = WrappedBridge.SwiftType?

  public static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject? {
    if let value {
      var args = [jvalue()]
      args[0].l = WrappedBridge.toJavaObject(value, in: environment)
      return environment.interface.CallStaticObjectMethodA(
        environment,
        _JNIMethodIDCache.JavaOptional.class,
        _JNIMethodIDCache.JavaOptional.of,
        &args
      )
    } else {
      return environment.interface.CallStaticObjectMethodA(
        environment,
        _JNIMethodIDCache.JavaOptional.class,
        _JNIMethodIDCache.JavaOptional.empty,
        nil
      )
    }
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> SwiftType {
    guard let obj else {
      fatalError("Optional.fromJavaObject received a null Java object")
    }

    let isPresent = environment.interface.CallBooleanMethodA(
      environment,
      obj,
      _JNIMethodIDCache.JavaOptional.isPresent,
      nil
    )
    guard isPresent == JNI_TRUE else {
      return nil
    }

    let wrapped = environment.interface.CallObjectMethodA(
      environment,
      obj,
      _JNIMethodIDCache.JavaOptional.get,
      nil
    )
    return WrappedBridge.fromJavaObject(wrapped, in: environment)
  }

  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    try body(_JNIMethodIDCache.JavaOptional.class)
  }
}

public enum ArrayBridge<ElementBridge: JobjectBridge>: JobjectBridge {
  public typealias SwiftType = [ElementBridge.SwiftType]

  public static func toJavaObject(_ value: SwiftType, in environment: JNIEnvironment) -> jobject? {
    try! ElementBridge.withJNIClass(in: environment) { elementClass in
      guard let array = environment.interface.NewObjectArray(
        environment,
        jsize(value.count),
        elementClass,
        nil
      ) else {
        fatalError("Array.toJavaObject failed to allocate a Java array")
      }

      for (i, element) in value.enumerated() {
        let javaElement = ElementBridge.toJavaObject(element, in: environment)
        environment.interface.SetObjectArrayElement(environment, array, jsize(i), javaElement)
      }
      return array
    }
  }

  public static func fromJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> SwiftType {
    guard let obj else {
      fatalError("Array.fromJavaObject received a null Java object")
    }

    let array = unsafeBitCast(obj, to: jobjectArray?.self)
    let count = Int(environment.interface.GetArrayLength(environment, array))
    var result: SwiftType = []
    result.reserveCapacity(count)

    for i in 0..<count {
      let javaElement = environment.interface.GetObjectArrayElement(environment, array, jsize(i))
      result.append(ElementBridge.fromJavaObject(javaElement, in: environment))
    }

    return result
  }

  public static func withJNIClass<Result>(
    in environment: JNIEnvironment,
    _ body: (jclass) throws -> Result
  ) throws -> Result {
    try ElementBridge.withJNIClass(in: environment) { elementClass in
      guard let array = environment.interface.NewObjectArray(environment, 0, elementClass, nil) else {
        fatalError("Array.withJNIClass failed to allocate a Java array")
      }
      defer {
        environment.interface.DeleteLocalRef(environment, array)
      }

      guard let arrayClass = environment.interface.GetObjectClass(environment, array) else {
        fatalError("Array.withJNIClass could not load the Java array class")
      }
      defer {
        environment.interface.DeleteLocalRef(environment, arrayClass)
      }

      return try body(arrayClass)
    }
  }
}
