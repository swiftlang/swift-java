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
import SwiftJavaConfigurationShared
import SwiftParser
import SwiftSyntax

/// Drives the analysis of Swift source code into an `AnalysisResult` that
/// downstream language generators (e.g. Java/JNI/FFM, others) can consume
///
/// The analysis is language-neutral; language-specific extraction rules
/// (such as honoring Java's `@JavaExport` or skipping `@JavaClass`-wrapped
/// types) are layered in via an optional `ExtractDecider`
public final class SwiftAnalyzer {
  static let SWIFT_INTERFACE_SUFFIX = ".swiftinterface"

  package var log: Logger

  package let config: Configuration

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

  package var importedGlobalVariables: [ImportedFunc] = []

  package var importedGlobalFuncs: [ImportedFunc] = []

  /// A mapping from Swift type names (e.g., A.B) over to the imported nominal
  /// type representation.
  package var importedTypes: [String: ImportedNominalType] = [:]

  /// Specializations of generic types that will get their concrete Java declarations, "as if" they were independent types
  package var specializations: [ImportedNominalType: Set<ImportedNominalType>] = [:]

  package var lookupContext: SwiftTypeLookupContext! = nil

  package var symbolTable: SwiftSymbolTable! {
    lookupContext?.symbolTable
  }

  /// Optional language-specific extraction decider that can override the
  /// built-in access-level filter on a per-decl basis
  package let extractDecider: (any ExtractDecider)?

  public init(
    config: Configuration,
    extractDecider: (any ExtractDecider)? = nil
  ) {
    guard let swiftModule = config.swiftModule else {
      fatalError("Missing 'swiftModule' name.") // FIXME: can we make it required in config? but we shared config for many cases
    }
    self.log = Logger(label: "translator", logLevel: config.logLevel ?? .info)
    self.config = config
    self.swiftModuleName = swiftModule
    self.extractDecider = extractDecider

    if let staticBuildConfigPath = config.staticBuildConfigurationFile {
      do {
        let data = try Data(contentsOf: URL(fileURLWithPath: staticBuildConfigPath))
        let decoder = JSONDecoder()
        self.buildConfig = try decoder.decode(StaticBuildConfiguration.self, from: data)
        self.log.info("Using custom static build configuration from: \(staticBuildConfigPath)")
      } catch {
        fatalError("Failed to load static build configuration from '\(staticBuildConfigPath)': \(error)")
      }
    } else {
      self.buildConfig = .swiftExtractDefault
    }
  }
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Analysis

extension SwiftAnalyzer {
  /// Snapshot of the analysis state as a value-typed `AnalysisResult`.
  public var result: AnalysisResult {
    AnalysisResult(
      importedTypes: self.importedTypes,
      importedGlobalVariables: self.importedGlobalVariables,
      importedGlobalFuncs: self.importedGlobalFuncs,
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
    prepareForTranslation()

    let visitor = SwiftAnalysisVisitor(translator: self)

    for input in self.inputs {
      log.trace("Analyzing \(input.path)")
      visitor.visit(inputFile: input)
    }

    // Apply any specializations registered after their target types were visited
    visitor.applyPendingSpecializations()

    self.visitFoundationDeclsIfNeeded(with: visitor)
  }

  /// Top-level convenience: run analysis on the given Swift sources and return
  /// the resulting `AnalysisResult`. Useful for tests and for callers that only
  /// need analysis (no code generation).
  public static func analyze(
    sources: [(path: String, text: String)],
    moduleName: String,
    config: Configuration? = nil,
    sourceDependencies: SourceDependencies = SourceDependencies(),
    extractDecider: (any ExtractDecider)? = nil
  ) throws -> AnalysisResult {
    var effectiveConfig = config ?? Configuration()
    effectiveConfig.swiftModule = moduleName
    let translator = SwiftAnalyzer(config: effectiveConfig, extractDecider: extractDecider)
    translator.sourceDependencies = sourceDependencies
    for source in sources {
      translator.add(filePath: source.path, text: source.text)
    }
    try translator.analyze()
    return translator.result
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
  }

  /// Check if any of the imported decls uses a nominal declaration that satisfies
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
      case .genericParameter:
        return false
      }
    }

    func check(_ fn: ImportedFunc) -> Bool {
      if check(fn.functionSignature.result.type) {
        return true
      }
      if fn.functionSignature.parameters.contains(where: { check($0.type) }) {
        return true
      }
      return false
    }

    if self.importedGlobalFuncs.contains(where: check) {
      return true
    }
    if self.importedGlobalVariables.contains(where: check) {
      return true
    }
    for importedType in self.importedTypes.values {
      if importedType.initializers.contains(where: check) {
        return true
      }
      if importedType.methods.contains(where: check) {
        return true
      }
      if importedType.variables.contains(where: check) {
        return true
      }
    }
    return false
  }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Type translation
extension SwiftAnalyzer {
  /// Try to resolve the given nominal declaration node into its imported representation.
  func importedNominalType(
    _ nominalNode: some DeclGroupSyntax & NamedDeclSyntax & WithModifiersSyntax & WithAttributesSyntax,
    parent: ImportedNominalType?,
  ) -> ImportedNominalType? {
    if !nominalNode.shouldExtract(config: config, log: log, in: parent, decider: extractDecider) {
      return nil
    }

    guard let nominal = symbolTable.lookupType(nominalNode.name.text, parent: parent?.swiftNominal) else {
      return nil
    }
    return self.importedNominalType(nominal)
  }

  /// Try to resolve the given nominal type node into its imported representation.
  func importedNominalType(
    _ typeNode: TypeSyntax
  ) -> ImportedNominalType? {
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

    guard swiftNominalDecl.syntax.shouldExtract(config: config, log: log, in: nil as ImportedNominalType?, decider: extractDecider) else {
      return nil
    }

    return importedNominalType(swiftNominalDecl)
  }

  func importedNominalType(_ nominal: SwiftNominalTypeDeclaration) -> ImportedNominalType? {
    let fullName = nominal.qualifiedName

    guard shouldExtractSwiftType(qualifiedName: fullName, config: config) else {
      log.debug("Skip import '\(fullName)': filtered by swiftFilterInclude/swiftFilterExclude")
      return nil
    }

    if let alreadyImported = importedTypes[fullName] {
      return alreadyImported
    }

    let importedNominal = try? ImportedNominalType(swiftNominal: nominal, lookupContext: lookupContext)

    importedTypes[fullName] = importedNominal
    return importedNominal
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
