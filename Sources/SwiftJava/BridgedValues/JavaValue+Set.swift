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

// ==== -----------------------------------------------------------------------
// MARK: Set extension for JNI bridging

extension Set {
  /// Box this set and return a jlong pointer for passing across JNI.
  /// The set is retained on the Swift heap; Java holds the pointer.
  public func setGetJNIValue<ElementBridge: JobjectBridge>(
    in environment: JNIEnvironment,
    elementBridge: ElementBridge.Type
  ) -> jlong where ElementBridge.SwiftType == Element {
    let box = SwiftSetBox<ElementBridge>(self)
    let unmanaged = Unmanaged.passRetained(box)
    let rawPointer = unmanaged.toOpaque()
    return jlong(Int(bitPattern: rawPointer))
  }

  /// Reconstruct a Swift set from a JNI jlong pointer to a SwiftSetBox.
  public init<ElementBridge: JobjectBridge>(
    fromJNI value: jlong,
    in environment: JNIEnvironment,
    elementBridge: ElementBridge.Type
  ) where ElementBridge.SwiftType == Element {
    let rawPointer = UnsafeRawPointer(bitPattern: Int(value))!
    let box = Unmanaged<SwiftSetBox<ElementBridge>>.fromOpaque(rawPointer).takeUnretainedValue()
    self = box.set
  }
}
