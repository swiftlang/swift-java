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

import SwiftExtract
import SwiftSyntax
import Testing

@Suite
struct AttributesSuite {

  @Test
  func typeAttribute() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          @SomeAttr public struct Marked {}
          public struct Plain {}
          """
        )
      ],
      moduleName: "Test"
    )

    let marked = try #require(result.extractedTypes.values.first { $0.swiftNominal.name == "Marked" })
    let plain = try #require(result.extractedTypes.values.first { $0.swiftNominal.name == "Plain" })

    #expect(marked.attribute(named: "SomeAttr") != nil)
    #expect(plain.attribute(named: "SomeAttr") == nil)
  }

  @Test
  func funcAttribute() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          @SomeAttr("customName", namespace: "Utils") public func greet() {}
          """
        )
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "greet" })
    let attr = try #require(fn.attribute(named: "SomeAttr"))
    let text = attr.trimmedDescription
    #expect(text.contains("\"customName\""))
    #expect(text.contains("namespace: \"Utils\""))
  }

}
