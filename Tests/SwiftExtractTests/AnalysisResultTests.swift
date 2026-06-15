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

/// End-to-end tests that drive the analysis pipeline (Swift source →
/// `AnalysisResult`) without touching any code-generation layer. These verify
/// `SwiftExtract` produces a correct analysis snapshot independent of any
/// downstream language target.
@Suite("AnalysisResult")
struct AnalysisResultSuite {

  // ==== -----------------------------------------------------------------------
  // MARK: Top-level types

  @Test func topLevelTypesAreRecorded() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct Tank<Fish> {
            public init() {}
          }
          public class FishTank {
            public init() {}
          }
          public enum Status {
            case open, closed
          }
          """
        )
      ],
      moduleName: "Aquarium"
    )

    #expect(result.extractedTypes["Tank"] != nil)
    #expect(result.extractedTypes["FishTank"] != nil)
    #expect(result.extractedTypes["Status"] != nil)

    let tank = try #require(result.extractedTypes["Tank"])
    #expect(tank.swiftNominal.kind == .struct)
    #expect(tank.swiftNominal.isGeneric)

    let fishTank = try #require(result.extractedTypes["FishTank"])
    #expect(fishTank.swiftNominal.kind == .class)

    let status = try #require(result.extractedTypes["Status"])
    #expect(status.swiftNominal.kind == .enum)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Methods on a type

  @Test func methodsAreRecordedOnEnclosingType() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public class FishTank {
            public init() {}
            public func feed() {}
            public func count() -> Int { 0 }
          }
          """
        )
      ],
      moduleName: "Aquarium"
    )

    let fishTank = try #require(result.extractedTypes["FishTank"])
    let methodNames = Set(fishTank.methods.map(\.name))
    #expect(methodNames == ["feed", "count"])
    #expect(fishTank.initializers.count == 1)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Properties (variables) — getter/setter pair

  @Test func storedPropertyProducesGetterAndSetter() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public class FishTank {
            public init() {}
            public var capacity: Int = 0
          }
          """
        )
      ],
      moduleName: "Aquarium"
    )

    let fishTank = try #require(result.extractedTypes["FishTank"])
    let capacityAccessors = fishTank.variables.filter { $0.name == "capacity" }
    let kinds = Set(capacityAccessors.map(\.apiKind))
    #expect(kinds == [.getter, .setter])
  }

  @Test func readOnlyPropertyHasOnlyGetter() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public class FishTank {
            public init() {}
            public var name: String { "Fish Tank" }
          }
          """
        )
      ],
      moduleName: "Aquarium"
    )

    let fishTank = try #require(result.extractedTypes["FishTank"])
    let nameAccessors = fishTank.variables.filter { $0.name == "name" }
    let kinds = nameAccessors.map(\.apiKind)
    #expect(kinds == [.getter])
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Global functions and variables

  @Test func globalFunctionLandsInImportedGlobalFuncs() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public func feedAll() {}
          public func mood() -> String { "" }
          """
        )
      ],
      moduleName: "Aquarium"
    )

    let names = Set(result.extractedGlobalFuncs.map(\.name))
    #expect(names == ["feedAll", "mood"])
    #expect(result.extractedTypes.isEmpty)
  }

  @Test func globalVariableProducesGetterSetterPair() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public var globalCounter: Int = 0
          """
        )
      ],
      moduleName: "Aquarium"
    )

    let counterAccessors = result.extractedGlobalVariables.filter { $0.name == "globalCounter" }
    let kinds = Set(counterAccessors.map(\.apiKind))
    #expect(kinds == [.getter, .setter])
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Effect specifiers (throws / async)

  @Test func effectSpecifiersAreCapturedOnFunctionSignatures() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public func plain() {}
          public func throwing() throws {}
          public func asynchronous() async {}
          public func both() async throws {}
          """
        )
      ],
      moduleName: "Aquarium"
    )

    let byName = Dictionary(uniqueKeysWithValues: result.extractedGlobalFuncs.map { ($0.name, $0) })
    let plain = try #require(byName["plain"])
    #expect(plain.functionSignature.effectSpecifiers.isEmpty)

    let throwing = try #require(byName["throwing"])
    #expect(throwing.functionSignature.effectSpecifiers.contains(.throws))
    #expect(!throwing.functionSignature.effectSpecifiers.contains(.async))

    let asynchronous = try #require(byName["asynchronous"])
    #expect(asynchronous.functionSignature.effectSpecifiers.contains(.async))
    #expect(!asynchronous.functionSignature.effectSpecifiers.contains(.throws))

    let both = try #require(byName["both"])
    #expect(both.functionSignature.effectSpecifiers.contains(.async))
    #expect(both.functionSignature.effectSpecifiers.contains(.throws))
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Access-level filtering

  @Test func internalDeclarationsAreNotImportedByDefault() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public class Public {
            public init() {}
          }
          internal class Internal {
            init() {}
          }
          private class Private {
            init() {}
          }
          """
        )
      ],
      moduleName: "Aquarium"
    )

    #expect(result.extractedTypes["Public"] != nil)
    #expect(result.extractedTypes["Internal"] == nil)
    #expect(result.extractedTypes["Private"] == nil)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Filter include/exclude

  @Test func swiftFilterExcludeSkipsMatchingTypes() throws {
    var config = DefaultSwiftExtractConfiguration()
    config.swiftFilterExclude = ["Skip*"]

    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public class Tank {
            public init() {}
          }
          public class SkipMe {
            public init() {}
          }
          public class SkipAlso {
            public init() {}
          }
          """
        )
      ],
      moduleName: "Aquarium",
      config: config
    )

    #expect(result.extractedTypes["Tank"] != nil)
    #expect(result.extractedTypes["SkipMe"] == nil)
    #expect(result.extractedTypes["SkipAlso"] == nil)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Generic typealias produces a specialization

  @Test func genericTypealiasProducesSpecializationEntry() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct Tank<Element> {
            public init() {}
          }
          public struct Fish {}
          public typealias FishTank = Tank<Fish>
          """
        )
      ],
      moduleName: "Aquarium"
    )

    // Both the generic base and its specialization land in extractedTypes.
    #expect(result.extractedTypes["Tank"] != nil)
    let fishTank = try #require(result.extractedTypes["FishTank"])
    #expect(fishTank.isSpecialization)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Empty input

  @Test func emptyModuleProducesEmptyResult() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "// nothing here")
      ],
      moduleName: "Empty"
    )

    #expect(result.extractedTypes.isEmpty)
    #expect(result.extractedGlobalFuncs.isEmpty)
    #expect(result.extractedGlobalVariables.isEmpty)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Configuration knobs

  /// By default, initializers on an unspecialized generic type are NOT
  /// extracted: the open generic isn't directly constructible, so swift-java
  /// (and any caller leaving the knob at its default `false`) drops them.
  @Test func unspecializedGenericInitializersAreSkippedByDefault() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct Tank<Fish> {
            public init() {}
            public init(capacity: Int) {}
          }
          """
        )
      ],
      moduleName: "Aquarium"
    )

    let tank = try #require(result.extractedTypes["Tank"])
    #expect(tank.swiftNominal.isGeneric)
    #expect(!tank.isSpecialization)
    #expect(tank.initializers.isEmpty)
  }

  /// Opting into `extractsGenericTypeInitializers` keeps the base type's
  /// initializers in the analysis result so post-analysis specializers can
  /// clone them onto a concrete `Tank<Fish>`.
  @Test func extractsGenericTypeInitializersKeepsBaseInitializers() throws {
    var config = DefaultSwiftExtractConfiguration()
    config.extractsGenericTypeInitializers = true

    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct Tank<Fish> {
            public init() {}
            public init(capacity: Int) {}
          }
          """
        )
      ],
      moduleName: "Aquarium",
      config: config
    )

    let tank = try #require(result.extractedTypes["Tank"])
    #expect(tank.swiftNominal.isGeneric)
    #expect(!tank.isSpecialization)
    #expect(tank.initializers.count == 2)
  }

  /// `#if canImport(<module>)` blocks are inactive by default for modules the
  /// build configuration doesn't know about — the type guarded behind them
  /// must not appear in the analysis result.
  @Test func canImportGuardedDeclsAreSkippedWhenModuleNotAvailable() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct AlwaysHere {
            public init() {}
          }
          #if canImport(MadeUpModule)
          public struct OnlyWhenImportable {
            public init() {}
          }
          #endif
          """
        )
      ],
      moduleName: "Aquarium"
    )

    #expect(result.extractedTypes["AlwaysHere"] != nil)
    #expect(result.extractedTypes["OnlyWhenImportable"] == nil)
  }

  /// Adding the module to `availableImportModules` activates the
  /// `#if canImport(<module>)` clause so its declarations are extracted.
  @Test func availableImportModulesActivatesCanImportClause() throws {
    var config = DefaultSwiftExtractConfiguration()
    config.availableImportModules = ["MadeUpModule"]

    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public struct AlwaysHere {
            public init() {}
          }
          #if canImport(MadeUpModule)
          public struct OnlyWhenImportable {
            public init() {}
          }
          #endif
          """
        )
      ],
      moduleName: "Aquarium",
      config: config
    )

    #expect(result.extractedTypes["AlwaysHere"] != nil)
    #expect(result.extractedTypes["OnlyWhenImportable"] != nil)
  }
}
