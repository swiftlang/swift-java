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
// MARK: Dictionary extension for JNI bridging

extension Dictionary where Key: JavaBoxable & Hashable, Value: JavaBoxable {
  /// Box this dictionary and return a jlong pointer for passing across JNI.
  /// The dictionary is retained on the Swift heap; Java holds the pointer.
  public func dictionaryGetJNIValue(in environment: JNIEnvironment) -> jlong {
    let box = SwiftDictionaryBox<Key, Value>(self)
    let unmanaged = Unmanaged.passRetained(box)
    let rawPointer = unmanaged.toOpaque()
    return jlong(Int(bitPattern: rawPointer))
  }

  /// Reconstruct a Swift dictionary from a JNI jlong pointer to a SwiftDictionaryBox.
  public init(fromJNI value: jlong, in environment: JNIEnvironment) {
    let rawPointer = UnsafeRawPointer(bitPattern: Int(value))!
    let box = Unmanaged<SwiftDictionaryBox<Key, Value>>.fromOpaque(rawPointer).takeUnretainedValue()
    self = box.dictionary
  }
}
