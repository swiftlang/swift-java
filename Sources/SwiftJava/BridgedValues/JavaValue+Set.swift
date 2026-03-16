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

extension Set where Element: JavaBoxable & Hashable {
  /// Box this set and return a jlong pointer for passing across JNI.
  /// The set is retained on the Swift heap; Java holds the pointer.
  public func setGetJNIValue(in environment: JNIEnvironment) -> jlong {
    let box = SwiftSetBox<Element>(self)
    let unmanaged = Unmanaged.passRetained(box)
    let rawPointer = unmanaged.toOpaque()
    return jlong(Int(bitPattern: rawPointer))
  }

  /// Reconstruct a Swift set from a JNI jlong pointer to a SwiftSetBox.
  public init(fromJNI value: jlong, in environment: JNIEnvironment) {
    let rawPointer = UnsafeRawPointer(bitPattern: Int(value))!
    let box = Unmanaged<SwiftSetBox<Element>>.fromOpaque(rawPointer).takeUnretainedValue()
    self = box.set
  }
}
