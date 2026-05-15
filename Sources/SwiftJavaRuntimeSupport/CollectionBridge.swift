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

  public static func isJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Bool {
    guard let obj else { return false }
    return environment.interface.IsInstanceOf(environment, obj, _JNIMethodIDCache.SwiftDictionaryMap.class) == JNI_TRUE
  }

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
}

public enum SetBridge<ElementBridge: JobjectBridge>: JobjectBridge where ElementBridge.SwiftType: Hashable {
  public typealias SwiftType = Set<ElementBridge.SwiftType>

  public static func isJavaObject(_ obj: jobject?, in environment: JNIEnvironment) -> Bool {
    guard let obj else { return false }
    return environment.interface.IsInstanceOf(environment, obj, _JNIMethodIDCache.SwiftSet.class) == JNI_TRUE
  }

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
}
