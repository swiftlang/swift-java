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

/// Extensions on nominal types owned by another module used to be discarded whole: both
/// the conformances they added and the members they contributed. These verify they are
/// recorded now, and equally that recording them does not turn the other module's type
/// into an emission target.
@Suite("CrossModuleExtensions")
struct CrossModuleExtensionsSuite {

  // ==== ----------------------------------------------------------------------
  // MARK: Same-module extensions are unaffected

  @Test("Extensions from same module dont record cross-module extension")
  func existingAnalysesRecordNothing() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Greetable {
            func greet() -> String
          }

          public struct Person: Greetable {
            public func greet() -> String { "hi" }
          }

          extension Person {
            public func shout() -> String { "HI" }
          }
          """
        )
      ],
      moduleName: "TestModule"
    )

    #expect(result.crossModuleExtensions.isEmpty)
    #expect(result.crossModuleExtensions.all.isEmpty)
    #expect(result.crossModuleExtensions.unresolved.isEmpty)

    // Present as extracted type, and extensions on it
    let person = try #require(result.extractedTypes["Person"])
    #expect(person.methods.contains { $0.name == "shout" })
    #expect(person.inheritedTypes.map(\.description) == ["Greetable"])

    // The conformance is observable through the query, attributed to this module
    let greetable = SwiftNominalIdentity(
      moduleName: "TestModule",
      typeName: SwiftQualifiedTypeName("Greetable")
    )
    let conformance = try #require(
      result.typesConforming(to: greetable).first { $0.type.leafName == "Person" }
    )
    #expect(conformance.type.moduleName == "TestModule")
    #expect(conformance.derivation == .stated)
    #expect(!conformance.isConditional)
  }

  /// Extensions on the module's own types must behave exactly as before: members merged
  /// onto the type, conformances merged into `inheritedTypes`, nothing recorded as
  /// cross-module
  @Test
  func ownedTypeExtensionsAreUnaffected() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          public struct Person {}
          extension Person: Labelable {
            public func greet() -> String { "hi" }
          }
          """
        )
      ],
      moduleName: "TestModule"
    )

    #expect(result.crossModuleExtensions.isEmpty)
    let person = try #require(result.extractedTypes["Person"])
    #expect(person.methods.map(\.name) == ["greet"])
    #expect(person.inheritedTypes.map(\.description) == ["Labelable"])
  }

  /// An owned type the user filtered out stays filtered out. Ownership rejection is not
  /// the same as belonging to another module, and must not be rerouted into the
  /// cross-module record
  @Test
  func filteredOwnedTypeIsNotRecordedAsCrossModule() throws {
    var config = DefaultSwiftExtractConfiguration(swiftModule: "TestModule")
    config.swiftFilterExclude = ["Person"]

    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          public struct Person {}
          extension Person: Labelable {
            public func greet() -> String { "hi" }
          }
          """
        )
      ],
      moduleName: "TestModule",
      config: config
    )

    #expect(result.extractedTypes["Person"] == nil)
    #expect(result.crossModuleExtensions.isEmpty)
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Conformance-only extensions

  @Test
  func conformanceOnStdlibTypeIsRecorded() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension String: Labelable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let recorded = try #require(result.crossModuleExtensions.all.first)
    #expect(recorded.extendedType.fullyQualifiedName == "Swift.String")
    #expect(recorded.addedConformances.map(\.description) == ["Labelable"])
    #expect(recorded.members.isEmpty)
    #expect(!recorded.isConditional)
  }

  /// The compatibility guarantee. Recording another module's type must not register it in
  /// `extractedTypes`, which every generator treats as its emission worklist
  @Test
  func recordingDoesNotMakeTheOtherModuleTypeAnEmissionTarget() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension String: Labelable {}
          extension Int { public func doubled() -> Int { self * 2 } }
          """
        )
      ],
      moduleName: "TestModule"
    )

    #expect(result.extractedTypes["String"] == nil)
    #expect(result.extractedTypes["Int"] == nil)
    // Only the module's own protocol is an emission target
    #expect(result.extractedTypes.keys.sorted() == ["Labelable"])
  }

  @Test
  func moduleSelectorSpellingResolvesTheSameWay() throws {
    // `.swiftinterface` files spell other modules' types with a module selector. SwiftExtract
    // ignores the selector and resolves by leaf name, which is what makes the
    // FoundationModels case work at all
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension Swift::String: Labelable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let recorded = try #require(result.crossModuleExtensions.all.first)
    #expect(recorded.extendedType.fullyQualifiedName == "Swift.String")
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Member-contributing extensions

  @Test
  func membersOnStdlibTypeAreRecorded() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          extension Int {
            public func doubled() -> Int { self * 2 }
            public var isZero: Bool { self == 0 }
          }
          """
        )
      ],
      moduleName: "TestModule"
    )

    let recorded = try #require(result.crossModuleExtensions.all.first)
    #expect(recorded.extendedType.fullyQualifiedName == "Swift.Int")
    #expect(recorded.addedConformances.isEmpty)
    #expect(recorded.members.methods.map(\.name) == ["doubled"])
    #expect(recorded.members.variables.contains { $0.name == "isZero" })
  }

  @Test
  func conformanceAndMembersAreBothRecorded() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension String: Labelable {
            public func shout() -> String { self }
          }
          """
        )
      ],
      moduleName: "TestModule"
    )

    let recorded = try #require(result.crossModuleExtensions.all.first)
    #expect(recorded.addedConformances.map(\.description) == ["Labelable"])
    #expect(recorded.members.methods.map(\.name) == ["shout"])
  }

  /// Two extensions on the same other-module type both land, and are retrievable together
  @Test
  func multipleExtensionsOnOneTypeAccumulate() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          public protocol Shoutable {}
          extension String: Labelable {}
          extension String: Shoutable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let string = SwiftNominalIdentity(moduleName: "Swift", typeName: SwiftQualifiedTypeName("String"))
    let onString = result.crossModuleExtensions.extensions(of: string)
    #expect(onString.count == 2)
    #expect(onString.flatMap { $0.addedConformances.map(\.description) } == ["Labelable", "Shoutable"])
    #expect(result.crossModuleExtensions.extendedTypes.map(\.fullyQualifiedName) == ["Swift.String"])
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Conditional extensions

  /// A conditional conformance on another module's generic. Recording happens before the
  /// `where`-clause handling that governs specialization matching, so this survives, and
  /// it is marked conditional so a consumer cannot mistake it for unconditional
  @Test
  func conditionalConformanceOnStdlibGenericIsRecordedAsConditional() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension Array: Labelable where Element: Labelable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let recorded = try #require(result.crossModuleExtensions.all.first)
    #expect(recorded.extendedType.fullyQualifiedName == "Swift.Array")
    #expect(recorded.addedConformances.map(\.description) == ["Labelable"])
    #expect(recorded.isConditional)
    #expect(!recorded.requirements.isEmpty)
    // A conformance-constrained extension on an *owned* type gets deferred and can reach
    // `extractedTypes` through the specialization flush. A type from another module returns
    // before the deferral, so that path must stay unreachable for it
    #expect(result.extractedTypes["Array"] == nil)
  }

  @Test
  func conditionalConformanceOnOptionalIsRecorded() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension Optional: Labelable where Wrapped: Labelable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let recorded = try #require(result.crossModuleExtensions.all.first)
    #expect(recorded.extendedType.fullyQualifiedName == "Swift.Optional")
    #expect(recorded.isConditional)
  }

  @Test
  func requirementWithUnresolvableTypeIsConditionalWithoutRequirements() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension Array: Labelable where Element: SomeProtocolThatDoesNotExist {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let recorded = try #require(result.crossModuleExtensions.all.first)
    #expect(recorded.extendedType.fullyQualifiedName == "Swift.Array")
    #expect(recorded.requirements.isEmpty)
    #expect(recorded.hasUnrepresentableRequirements)
    #expect(recorded.isConditional)

    // And it stays conditional when read back through the query
    let labelable = SwiftNominalIdentity(
      moduleName: "TestModule",
      typeName: SwiftQualifiedTypeName("Labelable")
    )
    let conformance = try #require(
      result.typesConforming(to: labelable).first { $0.type.leafName == "Array" }
    )
    #expect(conformance.hasUnrepresentableRequirements)
    #expect(conformance.isConditional)
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Foundation types

  @Test
  func conformanceOnFoundationTypeIsRecorded() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          import Foundation
          public protocol Labelable {}
          extension Date: Labelable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let recorded = try #require(result.crossModuleExtensions.all.first)
    #expect(recorded.extendedType.leafName == "Date")
    #expect(recorded.extendedType.moduleName != "TestModule")
    #expect(result.extractedTypes["Date"] == nil)
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Unresolvable extended types

  @Test
  func unresolvableExtendedTypeIsRecordedSeparately() throws {
    let sink = CollectingDiagnosticsSink()
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension SomeTypeThatDoesNotExist: Labelable {}
          """
        )
      ],
      moduleName: "TestModule",
      diagnosticsSink: sink
    )

    #expect(result.crossModuleExtensions.all.isEmpty)
    let unresolved = try #require(result.crossModuleExtensions.unresolved.first)
    #expect(unresolved.extendedTypeDescription == "SomeTypeThatDoesNotExist")
    #expect(result.extractedTypes["SomeTypeThatDoesNotExist"] == nil)

    // Make sure this is diagnosed
    let diagnostic = try #require(sink.diagnostics.first)
    #expect(diagnostic.kind == .skippedDeclaration)
    #expect(diagnostic.declarationName == "extension SomeTypeThatDoesNotExist")
    #expect(diagnostic.moduleName == "TestModule")
    #expect(diagnostic.sourceFilePath == "/fake/Source.swift")
    #expect(diagnostic.message.contains("did not resolve"))
    #expect(diagnostic.node.is(ExtensionDeclSyntax.self))
    #expect(diagnostic.underlyingError == nil)
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Transitive conformance query

  @Test
  func conformanceIsFoundThroughProtocolInheritance() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol PromptRepresentable {}
          public protocol ConvertibleToGeneratedContent: PromptRepresentable {}
          public protocol Generable: ConvertibleToGeneratedContent {}

          public struct Widget: Generable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let promptRepresentable = SwiftNominalIdentity(
      moduleName: "TestModule",
      typeName: SwiftQualifiedTypeName("PromptRepresentable")
    )
    let conformers = result.typesConforming(to: promptRepresentable)

    let widget = try #require(conformers.first { $0.type.leafName == "Widget" })
    guard case .inherited(let via) = widget.derivation else {
      Issue.record("expected Widget's conformance to be inherited, got \(widget.derivation)")
      return
    }
    #expect(via.map(\.leafName) == ["Generable", "ConvertibleToGeneratedContent"])
    #expect(!widget.isConditional)
  }

  @Test
  func unrelatedProtocolYieldsNoConformers() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Greetable {}
          public protocol Unrelated {}
          public struct Person: Greetable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let unrelated = SwiftNominalIdentity(
      moduleName: "TestModule",
      typeName: SwiftQualifiedTypeName("Unrelated")
    )
    #expect(result.typesConforming(to: unrelated).isEmpty)
  }

  @Test
  func cyclicRefinementTerminates() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol A: B {}
          public protocol B: A {}
          public struct Thing: A {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let target = SwiftNominalIdentity(moduleName: "TestModule", typeName: SwiftQualifiedTypeName("B"))
    let conformers = result.typesConforming(to: target)
    #expect(conformers.contains { $0.type.leafName == "Thing" })
  }

  @Test
  func refiningProtocolsAreNotReportedAsConformers() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Base {}
          public protocol Refined: Base {}
          public struct Thing: Refined {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let base = SwiftNominalIdentity(moduleName: "TestModule", typeName: SwiftQualifiedTypeName("Base"))
    let conformers = result.typesConforming(to: base)
    #expect(conformers.contains { $0.type.leafName == "Thing" })
    #expect(!conformers.contains { $0.type.leafName == "Refined" })
  }

  @Test
  func specializationConformsUnderItsOwnIdentity() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          public struct Fish {}
          public struct Tank<Element>: Labelable {}
          public typealias FishTank = Tank<Fish>
          """
        )
      ],
      moduleName: "TestModule"
    )

    let fishTank = try #require(result.extractedTypes["FishTank"])
    #expect(fishTank.identity.fullyQualifiedName == "TestModule.FishTank")
    #expect(fishTank.identity.qualifiedName == fishTank.effectiveTypeName)
    // The base nominal it delegates to is still `Tank`
    #expect(fishTank.swiftNominal.identity.fullyQualifiedName == "TestModule.Tank")

    let labelable = SwiftNominalIdentity(
      moduleName: "TestModule",
      typeName: SwiftQualifiedTypeName("Labelable")
    )
    let conformers = result.typesConforming(to: labelable).map(\.type.fullyQualifiedName).sorted()
    #expect(conformers == ["TestModule.FishTank", "TestModule.Tank"])
  }

  @Test
  func stdlibTypeIsFoundThroughTransitiveConformance() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol PromptRepresentable {}
          public protocol ConvertibleToGeneratedContent: PromptRepresentable {}
          public protocol Generable: ConvertibleToGeneratedContent {}

          extension String: PromptRepresentable {}
          extension Int: Generable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let promptRepresentable = SwiftNominalIdentity(
      moduleName: "TestModule",
      typeName: SwiftQualifiedTypeName("PromptRepresentable")
    )
    let conformers = result.typesConforming(to: promptRepresentable)
    let byName = Dictionary(uniqueKeysWithValues: conformers.map { ($0.type.fullyQualifiedName, $0) })

    // Direct
    let string = try #require(byName["Swift.String"])
    #expect(string.derivation == .stated)
    #expect(!string.isConditional)

    // Two hops of protocol inheritance
    let int = try #require(byName["Swift.Int"])
    guard case .inherited(let via) = int.derivation else {
      Issue.record("expected Int's conformance to be inherited, got \(int.derivation)")
      return
    }
    #expect(via.map(\.leafName) == ["Generable", "ConvertibleToGeneratedContent"])
  }

  @Test
  func conditionalConformanceSurfacesAsConditionalFromTheQuery() throws {
    let result = try analyze(
      sources: [
        (
          "/fake/Source.swift",
          """
          public protocol Labelable {}
          extension String: Labelable {}
          extension Array: Labelable where Element: Labelable {}
          """
        )
      ],
      moduleName: "TestModule"
    )

    let labelable = SwiftNominalIdentity(
      moduleName: "TestModule",
      typeName: SwiftQualifiedTypeName("Labelable")
    )
    let conformers = result.typesConforming(to: labelable)
    let byName = Dictionary(uniqueKeysWithValues: conformers.map { ($0.type.fullyQualifiedName, $0) })

    #expect(try #require(byName["Swift.String"]).isConditional == false)
    #expect(try #require(byName["Swift.Array"]).isConditional == true)
  }
}
