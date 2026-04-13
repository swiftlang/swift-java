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

@JavaImplementation("org.swift.swiftkit.core.foundation.Date")
extension Date {
  @JavaMethod("$init")
  static func _init(environment: UnsafeMutablePointer<JNIEnv?>!, timeIntervalSince1970: Double) -> Int64 {
    let result$ = UnsafeMutablePointer<Date>.allocate(capacity: 1)
    result$.initialize(to: Date(timeIntervalSince1970: timeIntervalSince1970))
    return Int64(Int(bitPattern: result$))
  }

  @JavaMethod("$getTimeIntervalSince1970")
  static func _getTimeIntervalSince1970(environment: UnsafeMutablePointer<JNIEnv?>!, selfPointer: Int64) -> Double {
    let selfPointer$ = UnsafeMutablePointer<Date>(bitPattern: Int(selfPointer))
    guard let selfPointer$ else {
      fatalError("selfPointer memory address was null in call to \(#function)!")
    }
    return selfPointer$.pointee.timeIntervalSince1970
  }

  @JavaMethod("$typeMetadataAddressDowncall")
  static func _typeMetadataAddressDowncall(environment: UnsafeMutablePointer<JNIEnv?>!) -> Int64 {
    let metadataPointer = unsafeBitCast(Date.self, to: UnsafeRawPointer.self)
    return Int64(Int(bitPattern: metadataPointer))
  }
}
