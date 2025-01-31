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

import JExtractSwift
import Testing

@Suite("C type system tests")
struct CTypeTests {
  @Test("Function declaration printing")
  func testFunctionDeclarationPrint() {
    let malloc = CFunction(
      resultType: .pointer(.void),
      name: "malloc",
      parameters: [
        CParameter(name: "size", type: .integral(.size_t))
      ],
      isVariadic: false
    )
    #expect(malloc.description == "void* malloc(size_t size)")

    let free = CFunction(
      resultType: .void,
      name: "free",
      parameters: [
        CParameter(name: "ptr", type: .pointer(.void))
      ],
      isVariadic: false
    )
    #expect(free.description == "void free(void* ptr)")

    let snprintf = CFunction(
      resultType: .integral(.signed(bits: 32)),
      name: "snprintf",
      parameters: [
        CParameter(name: "str", type: .pointer(.integral(.signed(bits: 8)))),
        CParameter(name: "size", type: .integral(.size_t)),
        CParameter(
          name: "format",
          type: .pointer(
            .qualified(
              const: true,
              volatile: false,
              type: .integral(.signed(bits: 8))
            )
          )
        )
      ],
      isVariadic: true
    )
    #expect(snprintf.description == "int32_t snprintf(int8_t* str, size_t size, int8_t const* format, ...)")
    #expect(snprintf.functionType.description == "int32_t(int8_t*, size_t, int8_t const*, ...)")

    let rand = CFunction(
      resultType: .integral(.signed(bits: 32)),
      name: "rand",
      parameters: [],
      isVariadic: false
    )
    #expect(rand.description == "int32_t rand(void)")
    #expect(rand.functionType.description == "int32_t(void)")
  }
}
