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

@JavaClass("org.swift.swiftkit.core.collections.SwiftSet")
open class SwiftSetJava: JavaObject {
}

@JavaImplementation("org.swift.swiftkit.core.collections.SwiftSet")
extension SwiftSetJava {

  private static func setBox(from pointer: Int) -> AnySwiftSetBox {
    let rawPointer = UnsafeRawPointer(bitPattern: pointer)!
    return Unmanaged<AnySwiftSetBox>.fromOpaque(rawPointer).takeUnretainedValue()
  }

  @JavaMethod("$size")
  public static func _setSize(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) -> Int32 {
    Int32(setBox(from: pointer).size())
  }

  @JavaMethod("$contains")
  public static func _setContains(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int, element: JavaObject?) -> Bool {
    let jElement = element?.javaThis
    return setBox(from: pointer).contains(element: jElement, environment: environment)
  }

  @JavaMethod("$toArray")
  public static func _setToArray(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) -> JavaObject? {
    guard let result = setBox(from: pointer).toArray(environment: environment) else { return nil }
    return JavaObject(javaThis: result, environment: environment)
  }

  @JavaMethod("$destroy")
  public static func _setDestroy(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) {
    let rawPointer = UnsafeRawPointer(bitPattern: Int(pointer))!
    Unmanaged<AnySwiftSetBox>.fromOpaque(rawPointer).release()
  }

  @JavaMethod("$typeMetadataAddress")
  public static func _setTypeMetadataAddress(environment: UnsafeMutablePointer<JNIEnv?>!, pointer: Int) -> Int {
    let set = setBox(from: pointer).setAsAny()
    let metatype = type(of: set)
    let metadataPointer = unsafeBitCast(metatype, to: UnsafeRawPointer.self)
    return Int(bitPattern: metadataPointer)
  }
}
