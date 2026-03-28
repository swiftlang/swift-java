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

import SwiftRuntimeFunctions
import Testing

@Suite("_swiftjava_stringToCString tests")
struct StringToCStringTests {

  @Test func ascii() {
    let cStr = _swiftjava_stringToCString("Hello")
    defer { cStr.deallocate() }

    #expect(String(cString: cStr) == "Hello")
  }

  @Test func empty() {
    let cStr = _swiftjava_stringToCString("")
    defer { cStr.deallocate() }

    #expect(cStr[0] == 0)
    #expect(String(cString: cStr) == "")
  }

  @Test func emoji() {
    let input = "hello 🦫 beaver!"
    let cStr = _swiftjava_stringToCString(input)
    defer { cStr.deallocate() }

    #expect(String(cString: cStr) == input)
  }

  @Test func roundTrip() {
    let input = "café ☕ naïve 日本語"
    let cStr = _swiftjava_stringToCString(input)
    defer { cStr.deallocate() }

    #expect(String(cString: cStr) == input)
  }
}
