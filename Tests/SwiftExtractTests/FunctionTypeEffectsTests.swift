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

@Suite
struct FunctionTypeEffectSpecifierSuite {

  private func closureParameterType(_ source: String) throws -> SwiftFunctionType {
    let result = try analyze(
      sources: [("/fake/Source.swift", source)],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "take" })
    guard case .function(let fnType) = fn.functionSignature.parameters[0].type else {
      throw TestError("expected .function parameter, got \(fn.functionSignature.parameters[0].type)")
    }
    return fnType
  }

  @Test
  func asyncClosureRecordsAsync() throws {
    let fnType = try closureParameterType("public func take(_ cb: () async -> Void) {}")

    #expect(fnType.effectSpecifiers == [.async])
    #expect(fnType.isAsync)
    #expect(!fnType.isThrowing)
  }

  @Test
  func throwingClosureRecordsThrows() throws {
    let fnType = try closureParameterType("public func take(_ cb: () throws -> Void) {}")

    #expect(fnType.effectSpecifiers == [.throws])
    #expect(!fnType.isAsync)
    #expect(fnType.isThrowing)
    #expect(!fnType.isTypedThrowing)
    #expect(fnType.thrownTypedError == nil)
  }

  @Test
  func typedThrowsClosureRecordsThrownErrorType() throws {
    let fnType = try closureParameterType(
      """
      public struct FishTankError: Error {}
      public func take(_ cb: () throws(FishTankError) -> Void) {}
      """
    )

    #expect(fnType.effectSpecifiers == [.throws])
    #expect(fnType.isThrowing)
    #expect(fnType.isTypedThrowing)
    #expect(fnType.thrownTypedError?.description == "FishTankError")
  }

  @Test
  func unresolvableThrownErrorTypeStillRecordsThrows() throws {
    let fnType = try closureParameterType("public func take(_ cb: () throws(NoSuchError) -> Void) {}")

    #expect(fnType.effectSpecifiers == [.throws])
    #expect(fnType.isThrowing)
    #expect(fnType.thrownTypedError == nil)
  }

  @Test
  func asyncThrowingClosureRecordsBoth() throws {
    let fnType = try closureParameterType("public func take(_ cb: () async throws -> Void) {}")

    #expect(fnType.effectSpecifiers == [.async, .throws])
    #expect(fnType.isAsync)
    #expect(fnType.isThrowing)
  }

  @Test
  func descriptionRendersEffectSpecifiers() throws {
    let fnType = try closureParameterType(
      "public func take(_ cb: @escaping (Int) async throws -> Void) {}"
    )

    #expect(fnType.description == "@escaping (Int) async throws -> Void")
  }

  @Test
  func descriptionRendersThrownErrorType() throws {
    let fnType = try closureParameterType(
      """
      public struct FishTankError: Error {}
      public func take(_ cb: @escaping (Int) async throws(FishTankError) -> Void) {}
      """
    )

    #expect(fnType.description == "@escaping (Int) async throws(FishTankError) -> Void")
  }

  @Test
  func effectsOnReturnedClosureAreRecorded() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public func get() -> () async -> Void { fatalError() }
          """
        )
      ],
      moduleName: "Test"
    )

    let fn = try #require(result.extractedGlobalFuncs.first { $0.name == "get" })
    guard case .function(let fnType) = fn.functionSignature.result.type else {
      Issue.record("expected .function result, got \(fn.functionSignature.result.type)")
      return
    }
    #expect(fnType.effectSpecifiers == [.async])
  }
}

private struct TestError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) {
    self.description = description
  }
}
