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

import JExtractSwiftLib
import Testing

@Suite
struct JNICDeclAttributesTests {

  @Test
  func globalFunc_hasUsedAttribute() throws {
    try assertOutput(
      input: "public func hello()",
      .jni,
      .swift,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_SwiftModule__00024hello__")
        ...
        """
      ]
    )
  }

  @Test
  func globalFuncWithArgs_hasUsedAttribute() throws {
    try assertOutput(
      input: "public func add(a: Int64, b: Int64) -> Int64",
      .jni,
      .swift,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @used
        #endif
        @_cdecl("Java_com_example_swift_SwiftModule__00024add__JJ")
        ...
        """
      ]
    )
  }
}
