//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JExtractSwift
import Testing

final class MethodThunkTests {
  let input =
    """
    import Swift

    public func globalFunc(a: Int32, b: Int64) {}
    public func globalFunc(a: Double, b: Int64) {}
    """

  @Test("Thunk overloads: globalFunc(a: Int32, b: Int64) & globalFunc(i32: Int32, l: Int64)")
  func thunk_overloads() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .trace

    try assertOutput(
      st, input: input, .swift,
      expectedChunks:
      [
        """
        @_cdecl()
        func kappa()
        """
      ]
    )
  }

}
