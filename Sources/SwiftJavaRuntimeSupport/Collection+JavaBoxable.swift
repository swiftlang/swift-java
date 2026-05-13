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

extension Dictionary: JavaBoxable where Key: JavaBoxable & Hashable, Value: JavaBoxable {
  public static var javaBoxClass: jclass {
    _JNIMethodIDCache.SwiftDictionaryMap.class
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
}

extension Set: JavaBoxable where Element: JavaBoxable & Hashable {
  public static var javaBoxClass: jclass {
    _JNIMethodIDCache.SwiftSet.class
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
}
