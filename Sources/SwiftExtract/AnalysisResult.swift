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

/// The complete analysis result of the analyzed Swift inputs.
/// This is used as the primary input to source generators, which then act on the analyzed decls.
public struct AnalysisResult {
  public var extractedTypes: [SwiftTypeName: ExtractedNominalType]
  public var extractedGlobalVariables: [ExtractedFunc]
  public var extractedGlobalFuncs: [ExtractedFunc]

  /// Extensions the analyzed module declares on nominal types from other modules.
  ///
  /// Separate from `extractedTypes`, since we're not declaring types here at all, just extensions.
  public var crossModuleExtensions: CrossModuleExtensions

  public init(
    extractedTypes: [SwiftTypeName: ExtractedNominalType],
    extractedGlobalVariables: [ExtractedFunc],
    extractedGlobalFuncs: [ExtractedFunc],
    crossModuleExtensions: CrossModuleExtensions = CrossModuleExtensions()
  ) {
    self.extractedTypes = extractedTypes
    self.extractedGlobalVariables = extractedGlobalVariables
    self.extractedGlobalFuncs = extractedGlobalFuncs
    self.crossModuleExtensions = crossModuleExtensions
  }

  /// Expands variadic functions into distinct overloads.
  public mutating func expandVariadicOverloads(maxOverloads: Int) {
    self.extractedGlobalFuncs = self.extractedGlobalFuncs.flatMap {
      $0.expandingVariadicOverloads(maxOverloads: maxOverloads)
    }

    for type in self.extractedTypes.values {
      type.methods = type.methods.flatMap { $0.expandingVariadicOverloads(maxOverloads: maxOverloads) }
      type.initializers = type.initializers.flatMap { $0.expandingVariadicOverloads(maxOverloads: maxOverloads) }
    }
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Conformance queries

/// A conformance the analysis observed, either stated directly or inherited
public struct ObservedConformance {
  /// How this conformance was derived
  public enum Derivation: Equatable {
    /// An inheritance clause named the protocol directly
    case stated
    /// Reached from a stated conformance by inheritance.
    case inherited(via: [SwiftNominalIdentity])
  }

  /// The conforming nominal
  public let type: SwiftNominalIdentity

  /// The protocol it conforms to
  public let protocolType: SwiftNominalIdentity

  public let derivation: Derivation

  /// Requirements guarding the *stated* conformance this was derived from.
  /// Empty when the conformance is unconditional.
  public let requirements: [SwiftGenericRequirement]

  /// True when the guarding `where` clause held a requirement the analyzer could not
  /// represent, so `requirements` is an incomplete picture.
  ///
  /// This can happen when a not-extracted type is used in a requirement.
  public let hasUnrepresentableRequirements: Bool

  public init(
    type: SwiftNominalIdentity,
    protocolType: SwiftNominalIdentity,
    derivation: Derivation,
    requirements: [SwiftGenericRequirement],
    hasUnrepresentableRequirements: Bool = false
  ) {
    self.type = type
    self.protocolType = protocolType
    self.derivation = derivation
    self.requirements = requirements
    self.hasUnrepresentableRequirements = hasUnrepresentableRequirements
  }

  /// Whether this conformance applies only under a `where` clause
  public var isConditional: Bool {
    !requirements.isEmpty || hasUnrepresentableRequirements
  }
}

extension AnalysisResult {

  /// Every nominal the analysis observed to conform to `protocolType`.
  public func typesConforming(to protocolType: SwiftNominalIdentity) -> [ObservedConformance] {
    var results: [ObservedConformance] = []
    var refinementCache: [SwiftNominalIdentity: [SwiftNominalIdentity]?] = [:]

    /// The protocols walked from `stated` up to and including `protocolType`, or nil when
    /// `stated` does not refine it. Empty when `stated` *is* `protocolType`
    func refinementPath(from stated: SwiftNominalIdentity) -> [SwiftNominalIdentity]? {
      if let cached = refinementCache[stated] { return cached }
      // Seed the cache before recursing so a cyclic inheritance clause in malformed
      // input cannot spin forever
      refinementCache[stated] = .some(nil)
      var path: [SwiftNominalIdentity]? = nil
      if stated == protocolType {
        path = []
      } else {
        for parent in inheritedProtocolIdentities(of: stated) {
          if let rest = refinementPath(from: parent) {
            path = [parent] + rest
            break
          }
        }
      }
      refinementCache[stated] = .some(path)
      return path
    }

    func consider(
      conformer: SwiftNominalIdentity,
      stated: SwiftNominalIdentity,
      requirements: [SwiftGenericRequirement],
      hasUnrepresentableRequirements: Bool
    ) {
      guard let path = refinementPath(from: stated) else { return }
      // `path` ends at `protocolType`. The reportable chain starts at what source
      // actually named and stops short of the protocol being asked about
      let via = Array(([stated] + path).dropLast())
      results.append(
        ObservedConformance(
          type: conformer,
          protocolType: protocolType,
          derivation: path.isEmpty ? .stated : .inherited(via: via),
          requirements: requirements,
          hasUnrepresentableRequirements: hasUnrepresentableRequirements
        )
      )
    }

    // Types this module declares, from their own inheritance clauses
    for name in extractedTypes.keys.sorted() {
      guard let type = extractedTypes[name], !type.swiftNominal.isProtocolKind else { continue }
      let conformer = type.identity
      for stated in protocolIdentities(in: type.inheritedTypes) {
        consider(
          conformer: conformer,
          stated: stated,
          requirements: [],
          hasUnrepresentableRequirements: false
        )
      }
    }

    // Other module's types, from the extensions that gave them conformances
    for record in crossModuleExtensions.all {
      for stated in protocolIdentities(in: record.addedConformances) {
        consider(
          conformer: record.extendedType,
          stated: stated,
          requirements: record.requirements,
          hasUnrepresentableRequirements: record.hasUnrepresentableRequirements
        )
      }
    }

    return results
  }

  /// The protocols `protocolType` refines, as far as this analysis can see them.
  ///
  /// Resolved through `extractedTypes`.
  private func inheritedProtocolIdentities(of protocolType: SwiftNominalIdentity) -> [SwiftNominalIdentity] {
    guard let declared = extractedTypes[protocolType.qualifiedName] else { return [] }
    return protocolIdentities(in: declared.inheritedTypes)
  }

  private func protocolIdentities(in types: [SwiftType]) -> [SwiftNominalIdentity] {
    types.compactMap { type in
      guard let decl = type.asNominalTypeDeclaration, decl.isProtocolKind else { return nil }
      return decl.identity
    }
  }
}

extension SwiftNominalTypeDeclaration {
  /// Whether this declaration is a protocol
  var isProtocolKind: Bool {
    kind == .protocol
  }
}
