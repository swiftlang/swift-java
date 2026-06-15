//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import Logging
import SwiftIfConfig
import SwiftParser
import SwiftSyntax

/// Drives the analysis of Swift source code into an `AnalysisResult` that
/// downstream language generators can consume.
public final class SwiftAnalyzer {
  static let SWIFT_INTERFACE_SUFFIX = ".swiftinterface"

  package var log: Logger

  package let config: any SwiftExtractConfiguration

  /// The build configuration used to resolve #if conditional compilation blocks.
  package let buildConfig: any BuildConfiguration

  /// The name of the Swift module being translated.
  package let swiftModuleName: String

  // ==== Input

  package var inputs: [SwiftInputFile] = []

  /// File paths that were skipped by swift filters but still need empty output
  /// files written (when --write-empty-files is set) so SwiftPM doesn't
  /// complain about missing declared outputs
  package var filteredOutPaths: [String] = []

  /// Sources jextract needs for symbol resolution but does not generate bindings
  /// for: wrapped Java classes plus real Swift sources from dependency modules.
  /// Populated by `SwiftToJava.run` before `analyze()` runs.
  package var sourceDependencies = SourceDependencies()

  // ==== Output state

  package var extractedGlobalVariables: [ExtractedFunc] = []

  package var extractedGlobalFuncs: [ExtractedFunc] = []

  /// A mapping from Swift type names (e.g., A.B) over to the extracted nominal
  /// type representation.
  package var extractedTypes: [String: ExtractedNominalType] = [:]

  /// Specializations of generic types that will get their concrete Java declarations, "as if" they were independent types
  package var specializations: [ExtractedNominalType: Set<ExtractedNominalType>] = [:]

  package var lookupContext: SwiftTypeLookupContext! = nil

  package var symbolTable: SwiftSymbolTable! {
    lookupContext?.symbolTable
  }

  /// Language-specific per-decl extraction policy. Every language target
  /// must supply one — pass `DefaultExtractDecider` for the
  /// access-level-only baseline.
  package let extractDecider: any ExtractDecider

  public init(
    config: any SwiftExtractConfiguration,
    moduleName: String? = nil,
    extractDecider: any ExtractDecider
  ) {
    guard let swiftModule = moduleName ?? config.swiftModule else {
      fatalError("Missing 'swiftModule' name.") // FIXME: can we make it required in config? but we shared config for many cases
    }
    self.log = Logger(label: "analyzer", logLevel: config.swiftExtractLogLevel ?? .info)
    self.config = config
    self.swiftModuleName = swiftModule
    self.extractDecider = extractDecider

    if let staticBuildConfigPath = config.staticBuildConfigurationFile {
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: staticBuildConfigPath))
        let decoder = JSONDecoder()
        let staticConfig = try decoder.decode(StaticBuildConfiguration.self, from: data)
        self.buildConfig = SwiftAnalyzer.overlayingAvailableModules(staticConfig, config.availableImportModules)
        self.log.info("Using custom static build configuration from: \(staticBuildConfigPath)")
      } catch {
        fatalError("Failed to load static build configuration from '\(staticBuildConfigPath)': \(error)")
      }
    } else {
      self.buildConfig = SwiftAnalyzer.overlayingAvailableModules(.swiftExtractDefault, config.availableImportModules)
    }
  }

  /// Overlay the configured extra importable modules onto a base build config
  /// (returns the base unchanged when none are configured).
  private static func overlayingAvailableModules<Base: BuildConfiguration>(
    _ base: Base,
    _ availableImportModules: Set<String>
  ) -> any BuildConfiguration {
    availableImportModules.isEmpty
      ? base
      : ImportOverlayBuildConfiguration(base: base, availableImportModules: availableImportModules)
  }
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Analysis

extension SwiftAnalyzer {
  /// Snapshot of the analysis state as a value-typed `AnalysisResult`.
  public var result: AnalysisResult {
    AnalysisResult(
      extractedTypes: self.extractedTypes,
      extractedGlobalVariables: self.extractedGlobalVariables,
      extractedGlobalFuncs: self.extractedGlobalFuncs,
    )
  }

  package func add(filePath: String, text: String) {
    log.debug("Adding: \(filePath)")
    let sourceFileSyntax = Parser.parse(source: text)
    self.inputs.append(SwiftInputFile(syntax: sourceFileSyntax, path: filePath))
  }

  /// Convenient method for analyzing single file.
  package func analyze(path: String, text: String) throws {
    self.add(filePath: path, text: text)
    try self.analyze()
  }

  /// Analyze registered inputs.
  package func analyze() throws {
    try analyze(beforeProcessingDeferredExtensions: { _ in })
  }

  /// Analyze registered inputs, with a hook that fires after the per-source
  /// walk has populated the specialization registry from any in-source
  /// `typealias Alias = Base<Args…>` declarations, but before the deferred
  /// constrained-extension queue is processed against those specializations.
  ///
  /// Downstream language code generators that drive specialization from a
  /// configuration source other than Swift typealiases (e.g. a `specialize:`
  /// config entry that names a base type by qualified name) can use the hook
  /// to call `registerSpecialization(_:outputName:typeArgs:)` so their
  /// specializations participate in `findMatchingSpecializations` alongside
  /// the analyzer's natively-registered ones. Without the hook, those
  /// specializations are registered too late and any constrained extension
  /// (`extension Box where T == ConcreteT { … }`) is silently dropped.
  package func analyze(
    beforeProcessingDeferredExtensions hook: (SwiftAnalyzer) throws -> Void
  ) throws {
    prepareForTranslation()

    let visitor = SwiftAnalysisVisitor(analyzer: self)

    for input in self.inputs {
      log.trace("Analyzing \(input.path)")
      visitor.visit(inputFile: input)
    }

    try hook(self)

    // Apply any specializations registered after their target types were visited
    visitor.applyPendingSpecializations()

    self.visitFoundationDeclsIfNeeded(with: visitor)
  }

  /// Register a specialization of a generic type, producing a concrete
  /// extracted type as if an in-source `typealias \(outputName) = \(baseQualifiedName)<…>`
  /// had been declared. Intended for use from the
  /// `analyze(beforeProcessingDeferredExtensions:)` hook so deferred
  /// constrained extensions can match against the registered specialization.
  ///
  /// The base type is resolved via the parsed module's symbol table by its
  /// qualified name (e.g. `"Box"`, `"ATHM.Server"`); returns `nil` if the
  /// base can't be found, isn't generic, or specialization fails.
  ///
  /// Note: this lower-cases over `ExtractedNominalType.specialize`, but unlike
  /// the visitor's typealias path it accepts already-substituted argument
  /// names (so callers that consume external configuration can pass the
  /// concrete type names directly without going through TypeSyntax parsing).
  @discardableResult
  public func registerSpecialization(
    baseQualifiedName: String,
    outputName: String,
    typeArgs: [String: String]
  ) -> ExtractedNominalType? {
    guard let base = resolveBaseForSpecialization(baseQualifiedName: baseQualifiedName) else {
      return nil
    }
    let specialized: ExtractedNominalType
    do {
      specialized = try base.specialize(as: outputName, with: typeArgs)
    } catch {
      log.warning("Failed to specialize \(base.baseTypeName) as \(outputName): \(error)")
      return nil
    }
    self.specializations[base, default: []].insert(specialized)
    log.info("Registered specialization (external): \(outputName) = \(base.baseTypeName)<\(typeArgs.values.joined(separator: ", "))>")
    return specialized
  }

  /// Like `registerSpecialization(baseQualifiedName:outputName:typeArgs:)`,
  /// but accepts positional generic arguments (matched in order to the
  /// base's generic parameters). Convenient for callers that scrape
  /// `typealias Foo = Bar<Args…>` from source syntax and don't already
  /// know the parameter names.
  @discardableResult
  public func registerSpecializationByPosition(
    baseQualifiedName: String,
    outputName: String,
    positionalArgs: [String]
  ) -> ExtractedNominalType? {
    guard let base = resolveBaseForSpecialization(baseQualifiedName: baseQualifiedName) else {
      return nil
    }
    var typeArgs: [String: String] = [:]
    for (i, name) in base.genericParameterNames.enumerated() where i < positionalArgs.count {
      typeArgs[name] = positionalArgs[i]
    }
    return registerSpecialization(
      baseQualifiedName: baseQualifiedName,
      outputName: outputName,
      typeArgs: typeArgs
    )
  }

  private func resolveBaseForSpecialization(baseQualifiedName: String) -> ExtractedNominalType? {
    let parts = baseQualifiedName.split(separator: ".").map(String.init)
    var resolvedBase: SwiftNominalTypeDeclaration? = nil
    var parent: SwiftNominalTypeDeclaration? = nil
    for part in parts {
      let next = symbolTable.lookupType(part, parent: parent)
      guard let next else { return nil }
      parent = next
      resolvedBase = next
    }
    guard let baseDecl = resolvedBase else { return nil }
    let base = self.extractedNominalType(baseDecl)
    guard let base, !base.genericParameterNames.isEmpty else { return nil }
    return base
  }

  /// The set of effective output names of every specialization currently
  /// registered with the analyzer (across all base types). Useful for
  /// callers driving `registerSpecialization` from a hook to skip names
  /// already registered by the analyzer's own typealias-decl visitor and
  /// avoid double-registering distinct `ExtractedNominalType` instances
  /// with the same effective output name.
  public var registeredSpecializationNames: Set<String> {
    Set(self.specializations.values.flatMap { $0 }.map(\.effectiveOutputName))
  }

  /// Top-level convenience: run analysis on the given Swift sources and return
  /// the resulting `AnalysisResult`.
  public static func analyze(
    sources: [(path: String, text: String)],
    moduleName: String,
    config: (any SwiftExtractConfiguration)? = nil,
    sourceDependencies: SourceDependencies = SourceDependencies(),
    extractDecider: any ExtractDecider
  ) throws -> AnalysisResult {
    try analyze(
      sources: sources,
      moduleName: moduleName,
      config: config,
      sourceDependencies: sourceDependencies,
      extractDecider: extractDecider,
      beforeProcessingDeferredExtensions: { _ in }
    )
  }

  /// Top-level convenience that accepts a hook fired after the per-source
  /// walk and before deferred-constrained-extension processing. See
  /// `SwiftAnalyzer.analyze(beforeProcessingDeferredExtensions:)` for the
  /// hook semantics. Use to drive specialization registration from
  /// downstream configuration sources (e.g. `specialize:` config entries)
  /// so deferred constrained extensions match against those specializations
  /// before they're dropped.
  public static func analyze(
    sources: [(path: String, text: String)],
    moduleName: String,
    config: (any SwiftExtractConfiguration)? = nil,
    sourceDependencies: SourceDependencies = SourceDependencies(),
    extractDecider: any ExtractDecider,
    beforeProcessingDeferredExtensions hook: (SwiftAnalyzer) throws -> Void
  ) throws -> AnalysisResult {
    let effectiveConfig = config ?? DefaultSwiftExtractConfiguration(swiftModule: moduleName)
    let analyzer = SwiftAnalyzer(config: effectiveConfig, moduleName: moduleName, extractDecider: extractDecider)
    analyzer.sourceDependencies = sourceDependencies
    for source in sources {
      analyzer.add(filePath: source.path, text: source.text)
    }
    try analyzer.analyze(beforeProcessingDeferredExtensions: hook)
    return analyzer.result
  }

  private func visitFoundationDeclsIfNeeded(with visitor: SwiftAnalysisVisitor) {
    // Each entry pairs a Foundation/FoundationEssentials counterpart so the
    // user-code reference can match either. Entries within the same group are
    // visited together when any one of the candidates is referenced — so using
    // Data also emits DataProtocol, etc.
    struct FoundationTypeGroup {
      let candidates: [SwiftKnownTypeDeclKind]
      let fakeSourceFilePath: String
    }
    let groups: [[FoundationTypeGroup]] = [
      [
        .init(
          candidates: [.foundationData, .essentialsData],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_DATA.swift",
        ),
        .init(
          candidates: [.foundationDataProtocol, .essentialsDataProtocol],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_DATAPROTOCOL.swift",
        ),
      ],
      [
        .init(
          candidates: [.foundationDate, .essentialsDate],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_DATE.swift",
        )
      ],
      [
        .init(
          candidates: [.foundationUUID, .essentialsUUID],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_UUID.swift",
        )
      ],
    ]

    for group in groups {
      let resolved: [(primary: SwiftNominalTypeDeclaration, source: String, candidates: [SwiftNominalTypeDeclaration])] =
        group.compactMap { type in
          let candidates = type.candidates.compactMap { self.symbolTable[$0] }
          guard let primary = candidates.first else {
            return nil
          }
          return (primary, type.fakeSourceFilePath, candidates)
        }
      guard !resolved.isEmpty else {
        continue
      }

      let allCandidates = resolved.flatMap(\.candidates)
      let isReferenced = self.isUsing(where: { decl in
        allCandidates.contains(where: { $0 === decl })
      })
      guard isReferenced else {
        continue
      }

      // Visit the fake source files, and register the types.
      for entry in resolved {
        visitor.visit(
          nominalDecl: entry.primary.syntax.asNominal!,
          in: nil,
          sourceFilePath: entry.source,
        )
      }
    }
  }

  package func prepareForTranslation() {
    let symbolTable = SwiftSymbolTable.setup(
      moduleName: self.swiftModuleName,
      inputs,
      config: self.config,
      sourceDependencies: self.sourceDependencies,
      buildConfig: self.buildConfig,
    )
    self.lookupContext = SwiftTypeLookupContext(symbolTable: symbolTable)
    self.lookupContext.permitsUnresolvedTypeReferences =
      self.config.permitsUnresolvedTypeReferences
  }

  /// Check if any of the extracted decls uses a nominal declaration that satisfies
  /// the given predicate.
  func isUsing(where predicate: (SwiftNominalTypeDeclaration) -> Bool) -> Bool {
    func check(_ type: SwiftType) -> Bool {
      switch type {
      case .nominal(let nominal):
        if nominal.genericArguments.contains(where: check) {
          return true
        }
        return predicate(nominal.nominalTypeDecl)
      case .tuple(let tuple):
        return tuple.contains(where: { check($0.type) })
      case .function(let fn):
        return check(fn.resultType) || fn.parameters.contains(where: { check($0.type) })
      case .metatype(let ty):
        return check(ty)
      case .existential(let ty), .opaque(let ty):
        return check(ty)
      case .composite(let types):
        return types.contains(where: check)
      case .inlineArray(_, let element):
        return check(element)
      case .genericParameter:
        return false
      }
    }

    func check(_ fn: ExtractedFunc) -> Bool {
      if check(fn.functionSignature.result.type) {
        return true
      }
      if fn.functionSignature.parameters.contains(where: { check($0.type) }) {
        return true
      }
      return false
    }

    if self.extractedGlobalFuncs.contains(where: check) {
      return true
    }
    if self.extractedGlobalVariables.contains(where: check) {
      return true
    }
    for extractedType in self.extractedTypes.values {
      if extractedType.initializers.contains(where: check) {
        return true
      }
      if extractedType.methods.contains(where: check) {
        return true
      }
      if extractedType.variables.contains(where: check) {
        return true
      }
    }
    return false
  }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Type translation
extension SwiftAnalyzer {
  /// Try to resolve the given nominal declaration node into its extracted representation.
  func extractedNominalType(
    _ nominalNode: some DeclGroupSyntax & NamedDeclSyntax & WithModifiersSyntax & WithAttributesSyntax,
    parent: ExtractedNominalType?,
  ) -> ExtractedNominalType? {
    if !nominalNode.shouldExtract(config: config, log: log, in: parent, decider: extractDecider) {
      return nil
    }

    guard let nominal = symbolTable.lookupType(nominalNode.name.text, parent: parent?.swiftNominal) else {
      return nil
    }
    return self.extractedNominalType(nominal)
  }

  /// Try to resolve the given nominal type node into its extracted representation.
  func extractedNominalType(
    _ typeNode: TypeSyntax
  ) -> ExtractedNominalType? {
    guard let swiftType = try? SwiftType(typeNode, lookupContext: lookupContext) else {
      return nil
    }
    guard let swiftNominalDecl = swiftType.asNominalTypeDeclaration else {
      return nil
    }

    let isFromThisModule = swiftNominalDecl.moduleName == self.swiftModuleName
    let isFromStubbedModule = config.hasImportedModuleStub(moduleOfNominal: swiftNominalDecl.moduleName)
    let isFromDependencyModule = sourceDependencies.swiftModuleNames.contains(swiftNominalDecl.moduleName)
    guard isFromThisModule || isFromStubbedModule || isFromDependencyModule else {
      return nil
    }

    guard swiftNominalDecl.syntax.shouldExtract(config: config, log: log, in: nil as ExtractedNominalType?, decider: extractDecider) else {
      return nil
    }

    return extractedNominalType(swiftNominalDecl)
  }

  func extractedNominalType(_ nominal: SwiftNominalTypeDeclaration) -> ExtractedNominalType? {
    let fullName = nominal.qualifiedName

    guard shouldExtractSwiftType(qualifiedName: fullName, config: config) else {
      log.debug("Skip import '\(fullName)': filtered by swiftFilterInclude/swiftFilterExclude")
      return nil
    }

    if let alreadyExtracted = extractedTypes[fullName] {
      return alreadyExtracted
    }

    let extractedNominal = try? ExtractedNominalType(swiftNominal: nominal, lookupContext: lookupContext)

    extractedTypes[fullName] = extractedNominal
    return extractedNominal
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Errors

public struct SwiftAnalyzerError: Error {
  let message: String

  public init(message: String) {
    self.message = message
  }
}
