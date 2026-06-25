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

/// Verifies that `SwiftType` recognises Swift's `InlineArray<N, T>` (sugar
/// `[N of T]`) and surfaces the count + element separately so downstream
/// code generators can lower it to language-specific fixed-size shapes.
@Suite("InlineArray type parsing")
struct InlineArrayTypeSuite {

  // ==== -----------------------------------------------------------------------
  // MARK: Parsing the sugar form `[N of T]`

  @Test func sugarFormIsParsedAsInlineArray() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func take(_ a: [3 of Int]) {}")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    let paramType = fn.functionSignature.parameters[0].type

    guard case .inlineArray(let count, let element) = paramType else {
      Issue.record("expected .inlineArray, got \(paramType)")
      return
    }
    #expect(count == 3)
    let nominal = try #require(element.asNominalType)
    #expect(nominal.nominalTypeDecl.knownTypeKind == .int)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Underscore digit separator and radix prefixes

  @Test func underscoreSeparatedCountIsParsed() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func take(_ a: [1_024 of Double]) {}")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    guard case .inlineArray(let count, _) = fn.functionSignature.parameters[0].type else {
      Issue.record("expected .inlineArray")
      return
    }
    #expect(count == 1024)
  }

  @Test func hexCountIsParsed() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func take(_ a: [0xA of UInt8]) {}")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    guard case .inlineArray(let count, let element) = fn.functionSignature.parameters[0].type else {
      Issue.record("expected .inlineArray")
      return
    }
    #expect(count == 10)
    #expect(element.asNominalType?.nominalTypeDecl.knownTypeKind == .uint8)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Returns and result types

  @Test func returnTypeIsParsedAsInlineArray() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func get() -> [4 of Float] { fatalError() }")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "get" })
    guard case .inlineArray(let count, let element) = fn.functionSignature.result.type else {
      Issue.record("expected .inlineArray result")
      return
    }
    #expect(count == 4)
    #expect(element.asNominalType?.nominalTypeDecl.knownTypeKind == .float)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Nested inline arrays

  @Test func nestedInlineArrayIsParsed() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func take(_ a: [3 of [4 of Int]]) {}")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    guard case .inlineArray(let outerCount, let outerElem) = fn.functionSignature.parameters[0].type else {
      Issue.record("expected outer .inlineArray")
      return
    }
    #expect(outerCount == 3)
    guard case .inlineArray(let innerCount, let innerElem) = outerElem else {
      Issue.record("expected inner .inlineArray")
      return
    }
    #expect(innerCount == 4)
    #expect(innerElem.asNominalType?.nominalTypeDecl.knownTypeKind == .int)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Description (printed form)

  @Test func descriptionUsesSugarForm() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func take(_ a: [3 of Int]) {}")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    let paramType = fn.functionSignature.parameters[0].type
    #expect(paramType.description == "[3 of Int]")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Spelled-out generic form `InlineArray<N, T>`

  @Test func spelledOutGenericFormIsParsedAsInlineArray() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func take(_ a: InlineArray<3, Double>) {}")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    guard case .inlineArray(let count, let element) = fn.functionSignature.parameters[0].type else {
      Issue.record("expected .inlineArray, got \(fn.functionSignature.parameters[0].type)")
      return
    }
    #expect(count == 3)
    #expect(element.asNominalType?.nominalTypeDecl.knownTypeKind == .double)
  }

  @Test func moduleQualifiedSpelledOutFormIsParsedAsInlineArray() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func take(_ a: Swift.InlineArray<3, Double>) {}")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    guard case .inlineArray(let count, let element) = fn.functionSignature.parameters[0].type else {
      Issue.record("expected .inlineArray, got \(fn.functionSignature.parameters[0].type)")
      return
    }
    #expect(count == 3)
    #expect(element.asNominalType?.nominalTypeDecl.knownTypeKind == .double)
  }

  @Test func spelledOutFormAsFuncReturn() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func get() -> InlineArray<4, Float> { fatalError() }")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "get" })
    guard case .inlineArray(let count, let element) = fn.functionSignature.result.type else {
      Issue.record("expected .inlineArray result")
      return
    }
    #expect(count == 4)
    #expect(element.asNominalType?.nominalTypeDecl.knownTypeKind == .float)
  }

  @Test func spelledOutFormAsSubscriptReturn() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct FishTank3 {
            public subscript(index: Int) -> InlineArray<3, Double> { fatalError() }
            public subscript(column index: Int) -> InlineArray<3, Double> { fatalError() }
          }
          """
        )
      ],
      moduleName: "Test"
    )

    let fishTank = try #require(
      result.extractedTypes.values.first { $0.swiftNominal.name == "FishTank3" }
    )
    let subscriptGetters = fishTank.variables.filter { $0.apiKind == .subscriptGetter }
    #expect(subscriptGetters.count == 2)

    for getter in subscriptGetters {
      guard case .inlineArray(let count, let element) = getter.functionSignature.result.type else {
        Issue.record("expected .inlineArray subscript result for \(getter.signatureString)")
        continue
      }
      #expect(count == 3)
      #expect(element.asNominalType?.nominalTypeDecl.knownTypeKind == .double)
    }
  }

  @Test func descriptionFromSpelledOutFormUsesSugarRoundTrip() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public func take(_ a: InlineArray<3, Int>) {}")
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    let paramType = fn.functionSignature.parameters[0].type
    #expect(paramType.description == "[3 of Int]")
  }
}
