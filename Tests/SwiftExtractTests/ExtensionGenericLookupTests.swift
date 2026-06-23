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
import Testing

/// Verifies that bare references to a generic parameter from inside an
/// extension on the corresponding generic type resolve correctly.
@Suite("Extension generic parameter lookup")
struct ExtensionGenericLookupSuite {

  // ==== -----------------------------------------------------------------------
  // MARK: Unconstrained extension parameter and return types

  @Test func unconstrainedExtensionParamResolvesGenericParameter() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct Box<Element> {}
          extension Box {
            public mutating func append(_ x: Element) {}
          }
          """
        )
      ],
      moduleName: "Test"
    )

    let box = try #require(result.extractedTypes["Box"])
    let append = try #require(box.methods.first { $0.name == "append" })
    let paramType = append.functionSignature.parameters[0].type

    guard case .genericParameter(let decl) = paramType else {
      Issue.record("expected .genericParameter(Element), got \(paramType)")
      return
    }
    #expect(decl.name == "Element")
  }

  @Test func unconstrainedExtensionReturnResolvesGenericParameter() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct Box<Element> {
            private var storage: [Element] = []
          }
          extension Box {
            public func first() -> Element { storage[0] }
          }
          """
        )
      ],
      moduleName: "Test"
    )

    let box = try #require(result.extractedTypes["Box"])
    let first = try #require(box.methods.first { $0.name == "first" })
    let returnType = first.functionSignature.result.type

    guard case .genericParameter(let decl) = returnType else {
      Issue.record("expected .genericParameter(Element), got \(returnType)")
      return
    }
    #expect(decl.name == "Element")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Constrained extensions still resolve the generic parameter

  @Test func constrainedExtensionParamResolvesGenericParameter() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct Box<Element> {
            public init() {}
          }
          public typealias IntBox = Box<Int>
          extension Box where Element == Int {
            public mutating func replace(_ x: Element) {}
          }
          """
        )
      ],
      moduleName: "Test"
    )

    // The constrained extension folds into the IntBox specialization.
    let intBox = try #require(result.extractedTypes["IntBox"])
    let replace = try #require(intBox.methods.first { $0.name == "replace" })
    let paramType = replace.functionSignature.parameters[0].type

    guard case .genericParameter(let decl) = paramType else {
      Issue.record("expected .genericParameter(Element), got \(paramType)")
      return
    }
    #expect(decl.name == "Element")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: ExtractedNominalType.genericParameters typed accessor

  @Test func extractedNominalExposesGenericParameters() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct Tag {}
          public struct Box<Element> {
            public init() {}
          }
          public struct Pair<Key, Value> {}
          """
        )
      ],
      moduleName: "Test"
    )

    let tag = try #require(result.extractedTypes["Tag"])
    #expect(tag.genericParameters.isEmpty)

    let box = try #require(result.extractedTypes["Box"])
    #expect(box.genericParameters.count == 1)
    #expect(box.genericParameters[0].name == "Element")
    #expect(box.genericParameterNames == ["Element"])

    let pair = try #require(result.extractedTypes["Pair"])
    #expect(pair.genericParameters.map(\.name) == ["Key", "Value"])
  }
}
