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

import Testing

@Suite
struct SwiftEscapedNameTests {
  @Test
  func function() throws {
    try assertOutput(
      input: """
        public struct MyStruct {
          public func `guard`()
        }
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public void guard() {",
        "private static native void $guard(long selfPointer);",
      ],
    )
  }

  @Test
  func enumCase() throws {
    try assertOutput(
      input: """
        public enum MyEnum {
          case `let`
        }
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static MyEnum let(SwiftArena swiftArena) {",
        "record Let() implements Case {",
      ],
    )
  }
}
