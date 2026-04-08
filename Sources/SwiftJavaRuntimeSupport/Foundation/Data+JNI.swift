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

@JavaImplementation("org.swift.swiftkit.core.foundation.Data")
extension Data {
  @JavaMethod("$init")
  static func _init(environment: UnsafeMutablePointer<JNIEnv?>!, bytes: [UInt8]) -> Int64 {
    let result$ = UnsafeMutablePointer<Data>.allocate(capacity: 1)
    result$.initialize(to: Data(bytes))
    return Int64(Int(bitPattern: result$))
  }

  @JavaMethod("$getCount")
  static func _getCount(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64) -> Int64 {
    let selfPointer$ = UnsafeMutablePointer<Data>(bitPattern: Int(selfPointer))
    guard let selfPointer$ else {
      fatalError("selfPointer memory address was null in call to \(#function)!")
    }
    return Int64(selfPointer$.pointee.count)
  }

  @JavaMethod("$typeMetadataAddressDowncall")
  static func _typeMetadataAddressDowncall(environment: UnsafeMutablePointer<JNIEnv?>!) -> Int64 {
    let metadataPointer = unsafeBitCast(Data.self, to: UnsafeRawPointer.self)
    return Int64(Int(bitPattern: metadataPointer))
  }
}

#if compiler(>=6.3)
@used
#endif
@_cdecl("Java_org_swift_swiftkit_core_foundation_Data__00024toByteArray__J")
public func Java_org_swift_swiftkit_core_foundation_Data__00024toByteArray__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jbyteArray? {
  guard let env$ = environment else {
    fatalError("Missing JNIEnv in downcall to \(#function)")
  }
  assert(selfPointer != 0, "selfPointer memory address was null")
  let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
  guard let selfPointer$ = UnsafeMutablePointer<Data>(bitPattern: selfPointerBits$) else {
    fatalError("selfPointer memory address was null in call to \(#function)!")
  }
  return selfPointer$.pointee.withUnsafeBytes { buffer in
    buffer.getJNIValue(in: environment)
  }
}

#if compiler(>=6.3)
@used
#endif
@_cdecl("Java_org_swift_swiftkit_core_foundation_Data__00024toByteArrayIndirectCopy__J")
public func Java_org_swift_swiftkit_core_foundation_Data__00024toByteArrayIndirectCopy__J(
  environment: UnsafeMutablePointer<JNIEnv?>!,
  thisClass: jclass,
  selfPointer: jlong
) -> jbyteArray? {
  guard let env$ = environment else {
    fatalError("Missing JNIEnv in downcall to \(#function)")
  }
  assert(selfPointer != 0, "selfPointer memory address was null")
  let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: env$))
  guard let selfPointer$ = UnsafeMutablePointer<Data>(bitPattern: selfPointerBits$) else {
    fatalError("selfPointer memory address was null in call to \(#function)!")
  }
  // This is a double copy, we need to initialize the array and then copy into a JVM array in getJNIValue
  return [UInt8](selfPointer$.pointee).getJNIValue(in: environment)
}
