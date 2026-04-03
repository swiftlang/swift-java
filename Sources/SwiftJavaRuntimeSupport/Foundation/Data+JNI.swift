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

  @JavaMethod("$toByteArray")
  static func _toByteArray(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64) -> [UInt8] {
    let selfPointer$ = UnsafeMutablePointer<Data>(bitPattern: Int(selfPointer))
    guard let selfPointer$ else {
      fatalError("selfPointer memory address was null in call to \(#function)!")
    }
    return selfPointer$.pointee.withUnsafeBytes { buffer in
      return buffer.getJNIValue(in: environment)
    }
  }

  @JavaMethod("$toByteArrayIndirectCopy")
  static func _toByteArrayIndirectCopy(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64) -> [UInt8] {
    let selfPointer$ = UnsafeMutablePointer<Data>(bitPattern: Int(selfPointer))
    guard let selfPointer$ else {
      fatalError("selfPointer memory address was null in call to \(#function)!")
    }
    return [UInt8](selfPointer$.pointee)
  }

  @JavaMethod("$typeMetadataAddressDowncall")
  static func _typeMetadataAddressDowncall(environment: UnsafeMutablePointer<JNIEnv?>!) -> Int64 {
    let metadataPointer = unsafeBitCast(Data.self, to: UnsafeRawPointer.self)
    return Int64(Int(bitPattern: metadataPointer))
  }
}
