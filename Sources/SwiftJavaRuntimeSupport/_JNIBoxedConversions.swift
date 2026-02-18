//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CSwiftJavaJNI
import SwiftJava

public enum _JNIBoxedConversions {
  private static let booleanMethod = _JNIMethodIDCache.Method(
    name: "valueOf",
    signature: "(Z)Ljava/lang/Boolean;",
    isStatic: true
  )
  private static let byteMethod = _JNIMethodIDCache.Method(
    name: "valueOf",
    signature: "(B)Ljava/lang/Byte;",
    isStatic: true
  )
  private static let charMethod = _JNIMethodIDCache.Method(
    name: "valueOf",
    signature: "(C)Ljava/lang/Character;",
    isStatic: true
  )
  private static let shortMethod = _JNIMethodIDCache.Method(
    name: "valueOf",
    signature: "(S)Ljava/lang/Short;",
    isStatic: true
  )
  private static let intMethod = _JNIMethodIDCache.Method(
    name: "valueOf",
    signature: "(I)Ljava/lang/Integer;",
    isStatic: true
  )
  private static let longMethod = _JNIMethodIDCache.Method(
    name: "valueOf",
    signature: "(J)Ljava/lang/Long;",
    isStatic: true
  )
  private static let floatMethod = _JNIMethodIDCache.Method(
    name: "valueOf",
    signature: "(F)Ljava/lang/Float;",
    isStatic: true
  )
  private static let doubleMethod = _JNIMethodIDCache.Method(
    name: "valueOf",
    signature: "(D)Ljava/lang/Double;",
    isStatic: true
  )

  private static let booleanCache = _JNIMethodIDCache(
    className: "java/lang/Boolean",
    methods: [booleanMethod]
  )

  private static let byteCache = _JNIMethodIDCache(
    className: "java/lang/Byte",
    methods: [byteMethod]
  )
  private static let charCache = _JNIMethodIDCache(
    className: "java/lang/Character",
    methods: [charMethod]
  )

  private static let shortCache = _JNIMethodIDCache(
    className: "java/lang/Short",
    methods: [shortMethod]
  )
  private static let intCache = _JNIMethodIDCache(
    className: "java/lang/Integer",
    methods: [intMethod]
  )

  private static let longCache = _JNIMethodIDCache(
    className: "java/lang/Long",
    methods: [longMethod]
  )

  private static let floatCache = _JNIMethodIDCache(
    className: "java/lang/Float",
    methods: [floatMethod]
  )

  private static let doubleCache = _JNIMethodIDCache(
    className: "java/lang/Double",
    methods: [doubleMethod]
  )

  public static func box(_ value: jboolean, in env: JNIEnvironment) -> jobject {
    env.interface.CallStaticObjectMethodA(
      env,
      booleanCache.javaClass,
      booleanCache.methods[booleanMethod]!,
      [jvalue(z: value)]
    )!
  }

  public static func box(_ value: jbyte, in env: JNIEnvironment) -> jobject {
    env.interface.CallStaticObjectMethodA(env, byteCache.javaClass, byteCache.methods[byteMethod]!, [jvalue(b: value)])!
  }

  public static func box(_ value: jchar, in env: JNIEnvironment) -> jobject {
    env.interface.CallStaticObjectMethodA(env, charCache.javaClass, charCache.methods[charMethod]!, [jvalue(c: value)])!
  }

  public static func box(_ value: jshort, in env: JNIEnvironment) -> jobject {
    env.interface.CallStaticObjectMethodA(
      env,
      shortCache.javaClass,
      shortCache.methods[shortMethod]!,
      [jvalue(s: value)]
    )!
  }

  public static func box(_ value: jint, in env: JNIEnvironment) -> jobject {
    env.interface.CallStaticObjectMethodA(env, intCache.javaClass, intCache.methods[intMethod]!, [jvalue(i: value)])!
  }

  public static func box(_ value: jlong, in env: JNIEnvironment) -> jobject {
    env.interface.CallStaticObjectMethodA(env, longCache.javaClass, longCache.methods[longMethod]!, [jvalue(j: value)])!
  }

  public static func box(_ value: jfloat, in env: JNIEnvironment) -> jobject {
    env.interface.CallStaticObjectMethodA(
      env,
      floatCache.javaClass,
      floatCache.methods[floatMethod]!,
      [jvalue(f: value)]
    )!
  }

  public static func box(_ value: jdouble, in env: JNIEnvironment) -> jobject {
    env.interface.CallStaticObjectMethodA(
      env,
      doubleCache.javaClass,
      doubleCache.methods[doubleMethod]!,
      [jvalue(d: value)]
    )!
  }
}
