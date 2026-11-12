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
import SwiftJavaJNICore

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// Foundation values that cross to Java as standard Java types when jextract's `foundationTypesAsJavaTypes` is
// enabled. Each value is copied: `URL` <-> `java.net.URI`, `Date` <-> `java.util.Date` (milliseconds),
// `Data` <-> `byte[]`, `Locale` <-> `java.util.Locale` and `TimeZone` <-> `java.util.TimeZone`.

/// A `JavaValue` represented in Java by an object reference.
public protocol _JNIObjectJavaValue: JavaValue where JNIType == jobject? {
  /// The JNI name of the Java class, such as `java/net/URI`, used for arrays of this value.
  static var _jniClassName: String { get }
}

extension _JNIObjectJavaValue {
  public static var jvalueKeyPath: WritableKeyPath<jvalue, JNIType> { \.l }

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
      let elementClass = environment.interface.FindClass(environment, _jniClassName)
      defer { environment.interface.DeleteLocalRef(environment, elementClass) }
      return environment.interface.NewObjectArray(environment, size, elementClass, nil)
    }
  }

  public static func jniGetArrayRegion(in environment: JNIEnvironment) -> JNIGetArrayRegion<JNIType> {
    { environment, array, start, length, outPointer in
      let buffer = UnsafeMutableBufferPointer(start: outPointer, count: Int(length))
      for i in 0..<length {
        buffer.initializeElement(
          at: Int(i),
          to: environment.interface.GetObjectArrayElement(environment, array, start + i)
        )
      }
    }
  }

  public static func jniSetArrayRegion(in environment: JNIEnvironment) -> JNISetArrayRegion<JNIType> {
    { environment, array, start, length, inPointer in
      let buffer = UnsafeBufferPointer(start: inPointer, count: Int(length))
      for i in 0..<length {
        environment.interface.SetObjectArrayElement(environment, array, start + i, buffer[Int(i)])
      }
    }
  }

  public static var jniPlaceholderValue: jobject? {
    nil
  }
}

/// Reads a `java.lang.String` result and releases its local reference.
private func takeString(_ string: jobject?, in environment: JNIEnvironment) -> String {
  defer { environment.interface.DeleteLocalRef(environment, string) }
  return String(fromJNI: string, in: environment)
}

/// Calls a method of `object` that returns a `java.lang.String`.
private func callStringMethod(
  _ method: _JNIMethodIDCache.Method,
  of cache: _JNIMethodIDCache,
  on object: jobject,
  in environment: JNIEnvironment
) -> String {
  takeString(environment.interface.CallObjectMethodA(environment, object, cache[method]!, nil), in: environment)
}

/// Calls a static factory of `cache`'s class that takes one `java.lang.String`.
private func callStaticFactory(
  _ method: _JNIMethodIDCache.Method,
  of cache: _JNIMethodIDCache,
  with argument: String,
  in environment: JNIEnvironment
) -> jobject? {
  let string = argument.getJNIValue(in: environment)
  defer { environment.interface.DeleteLocalRef(environment, string) }
  return environment.interface.CallStaticObjectMethodA(
    environment,
    cache.javaClass,
    cache[method]!,
    [jvalue(l: string)]
  )
}

// ==== -----------------------------------------------------------------------
// MARK: URL <-> java.net.URI

private let uriCreate = _JNIMethodIDCache.Method(
  name: "create",
  signature: "(Ljava/lang/String;)Ljava/net/URI;",
  isStatic: true
)
private let uriToString = _JNIMethodIDCache.Method(name: "toString", signature: "()Ljava/lang/String;")
private let uriCache = _JNIMethodIDCache(className: "java/net/URI", methods: [uriCreate, uriToString])

extension URL: @retroactive JavaValue, _JNIObjectJavaValue {
  public typealias JNIType = jobject?

  public static var javaType: JavaType { .class(package: "java.net", name: "URI") }
  public static var _jniClassName: String { "java/net/URI" }

  public init(fromJNI value: jobject?, in environment: JNIEnvironment) {
    let string = callStringMethod(uriToString, of: uriCache, on: value!, in: environment)
    guard let url = URL(string: string) else {
      fatalError("java.net.URI '\(string)' is not a valid Swift URL")
    }
    self = url
  }

  public func getJNIValue(in environment: JNIEnvironment) -> jobject? {
    callStaticFactory(uriCreate, of: uriCache, with: absoluteString, in: environment)
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Date <-> java.util.Date

private let dateInit = _JNIMethodIDCache.Method(name: "<init>", signature: "(J)V")
private let dateGetTime = _JNIMethodIDCache.Method(name: "getTime", signature: "()J")
private let dateCache = _JNIMethodIDCache(className: "java/util/Date", methods: [dateInit, dateGetTime])

extension Date: @retroactive JavaValue, _JNIObjectJavaValue {
  public typealias JNIType = jobject?

  public static var javaType: JavaType { .class(package: "java.util", name: "Date") }
  public static var _jniClassName: String { "java/util/Date" }

  public init(fromJNI value: jobject?, in environment: JNIEnvironment) {
    let milliseconds = environment.interface.CallLongMethodA(environment, value!, dateCache[dateGetTime]!, nil)
    self.init(timeIntervalSince1970: Double(milliseconds) / 1000)
  }

  public func getJNIValue(in environment: JNIEnvironment) -> jobject? {
    let milliseconds = Int64((timeIntervalSince1970 * 1000).rounded(.down))
    return environment.interface.NewObjectA(
      environment,
      dateCache.javaClass,
      dateCache[dateInit]!,
      [jvalue(j: milliseconds)]
    )
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Data <-> byte[]

extension Data: @retroactive JavaValue, _JNIObjectJavaValue {
  public typealias JNIType = jobject?

  public static var javaType: JavaType { .array(.byte) }
  public static var _jniClassName: String { "[B" }

  public init(fromJNI value: jobject?, in environment: JNIEnvironment) {
    let count = environment.interface.GetArrayLength(environment, value)
    var data = Data(count: Int(count))
    data.withUnsafeMutableBytes { buffer in
      environment.interface.GetByteArrayRegion(
        environment,
        value,
        0,
        count,
        buffer.baseAddress?.assumingMemoryBound(to: jbyte.self)
      )
    }
    self = data
  }

  public func getJNIValue(in environment: JNIEnvironment) -> jobject? {
    let array = environment.interface.NewByteArray(environment, jsize(count))
    withUnsafeBytes { buffer in
      environment.interface.SetByteArrayRegion(
        environment,
        array,
        0,
        jsize(buffer.count),
        buffer.baseAddress?.assumingMemoryBound(to: jbyte.self)
      )
    }
    return array
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Locale <-> java.util.Locale

private let localeForLanguageTag = _JNIMethodIDCache.Method(
  name: "forLanguageTag",
  signature: "(Ljava/lang/String;)Ljava/util/Locale;",
  isStatic: true
)
private let localeToLanguageTag = _JNIMethodIDCache.Method(name: "toLanguageTag", signature: "()Ljava/lang/String;")
private let localeCache = _JNIMethodIDCache(
  className: "java/util/Locale",
  methods: [localeForLanguageTag, localeToLanguageTag]
)

extension Locale: @retroactive JavaValue, _JNIObjectJavaValue {
  public typealias JNIType = jobject?

  public static var javaType: JavaType { .class(package: "java.util", name: "Locale") }
  public static var _jniClassName: String { "java/util/Locale" }

  // Java language tags separate subtags with `-`, Swift locale identifiers with `_`.
  public init(fromJNI value: jobject?, in environment: JNIEnvironment) {
    let tag = callStringMethod(localeToLanguageTag, of: localeCache, on: value!, in: environment)
    self.init(identifier: String(tag.map { $0 == "-" ? "_" : $0 }))
  }

  public func getJNIValue(in environment: JNIEnvironment) -> jobject? {
    let tag = String(identifier.map { $0 == "_" ? "-" : $0 })
    return callStaticFactory(localeForLanguageTag, of: localeCache, with: tag, in: environment)
  }
}

// ==== -----------------------------------------------------------------------
// MARK: TimeZone <-> java.util.TimeZone

private let timeZoneGetTimeZone = _JNIMethodIDCache.Method(
  name: "getTimeZone",
  signature: "(Ljava/lang/String;)Ljava/util/TimeZone;",
  isStatic: true
)
private let timeZoneGetID = _JNIMethodIDCache.Method(name: "getID", signature: "()Ljava/lang/String;")
private let timeZoneGetRawOffset = _JNIMethodIDCache.Method(name: "getRawOffset", signature: "()I")
private let timeZoneCache = _JNIMethodIDCache(
  className: "java/util/TimeZone",
  methods: [timeZoneGetTimeZone, timeZoneGetID, timeZoneGetRawOffset]
)

extension TimeZone: @retroactive JavaValue, _JNIObjectJavaValue {
  public typealias JNIType = jobject?

  public static var javaType: JavaType { .class(package: "java.util", name: "TimeZone") }
  public static var _jniClassName: String { "java/util/TimeZone" }

  public init(fromJNI value: jobject?, in environment: JNIEnvironment) {
    let identifier = callStringMethod(timeZoneGetID, of: timeZoneCache, on: value!, in: environment)
    if let timeZone = TimeZone(identifier: identifier) {
      self = timeZone
      return
    }
    // A Java ID Swift doesn't know, such as a custom "GMT+05:30": keep its offset.
    let milliseconds = environment.interface.CallIntMethodA(
      environment,
      value!,
      timeZoneCache[timeZoneGetRawOffset]!,
      nil
    )
    self = TimeZone(secondsFromGMT: Int(milliseconds) / 1000)!
  }

  public func getJNIValue(in environment: JNIEnvironment) -> jobject? {
    callStaticFactory(timeZoneGetTimeZone, of: timeZoneCache, with: identifier, in: environment)
  }
}
