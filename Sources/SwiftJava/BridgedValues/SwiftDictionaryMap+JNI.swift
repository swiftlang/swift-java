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

import SwiftJavaJNICore

@JavaClass("org.swift.swiftkit.core.collections.SwiftDictionaryMap")
open class SwiftDictionaryMapJava: JavaObject {
}

@JavaImplementation("org.swift.swiftkit.core.collections.SwiftDictionaryMap")
extension SwiftDictionaryMapJava {

  private static func box(from pointer: Int) -> AnySwiftDictionaryBox {
    let rawPointer = UnsafeRawPointer(bitPattern: pointer)!
    return Unmanaged<AnySwiftDictionaryBox>.fromOpaque(rawPointer).takeUnretainedValue()
  }

  @JavaMethod("$size")
  public static func _size(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) -> Int32 {
    Int32(box(from: pointer).size())
  }

  @JavaMethod("$get")
  public static func _get(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int, key: JavaObject?) -> JavaObject? {
    let jKey = key?.javaThis
    let box = box(from: pointer)
    guard let result = box.get(key: jKey, environment: environment) else {
      return nil
    }
    return JavaObject(javaThis: result, environment: environment)
  }

  @JavaMethod("$containsKey")
  public static func _containsKey(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int, key: JavaObject?) -> Bool {
    let jKey = key?.javaThis
    return box(from: pointer).containsKey(key: jKey, environment: environment)
  }

  @JavaMethod("$keys")
  public static func _keys(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) -> JavaObject? {
    guard let result = box(from: pointer).keys(environment: environment) else { return nil }
    return JavaObject(javaThis: result, environment: environment)
  }

  @JavaMethod("$values")
  public static func _values(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) -> JavaObject? {
    guard let result = box(from: pointer).values(environment: environment) else { return nil }
    return JavaObject(javaThis: result, environment: environment)
  }

  @JavaMethod("$destroy")
  public static func _destroy(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) {
    let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer))!
    Unmanaged<AnySwiftDictionaryBox>.fromOpaque(rawPointer).release()
  }

  @JavaMethod("$typeMetadataAddress")
  public static func _typeMetadataAddress(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) -> Int {
    let dictionary = box(from: pointer).dictionaryAsAny()
    let metatype = type(of: dictionary)
    let metadataPointer = unsafeBitCast(metatype, to: UnsafeRawPointer.self)
    return Int(bitPattern: metadataPointer)
  }
}
