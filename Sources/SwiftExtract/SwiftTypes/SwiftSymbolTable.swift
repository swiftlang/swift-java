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

import Logging
import SwiftIfConfig
import SwiftJavaConfigurationShared
import SwiftParser
import SwiftSyntax

public protocol SwiftSymbolTableProtocol {
  /// The module name that this symbol table describes.
  var moduleName: String { get }

  /// Look for a top-level nominal type with the given name. This should only
  /// return nominal types within this module.
  func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration?

  /// Look for a top-level typealias with the given name.
  func lookupTopLevelTypealias(_ name: String) -> SwiftTypeAliasDeclaration?

  // Look for a nested type with the given name.
  func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration?

  // Look for a nested typealias with the given name.
  func lookupNestedTypealias(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftTypeAliasDeclaration?
}

extension SwiftSymbolTableProtocol {
  /// Look for a type
  public func lookupType(_ name: String, parent: SwiftNominalTypeDeclaration?) -> SwiftNominalTypeDeclaration? {
    if let parent {
      return lookupNestedType(name, parent: parent)
    }

    return lookupTopLevelNominalType(name)
  }

  public func lookupTypealias(_ name: String, parent: SwiftNominalTypeDeclaration?) -> SwiftTypeAliasDeclaration? {
    if let parent {
      return lookupNestedTypealias(name, parent: parent)
    }

    return lookupTopLevelTypealias(name)
  }
}

public class SwiftSymbolTable {
  public let importedModules: [String: SwiftModuleSymbolTable]
  public let parsedModule: SwiftModuleSymbolTable

  /// Module names within `importedModules` that are synthetic — they exist
  /// purely to drive type resolution and must NOT be emitted as
  /// `import <module>` statements in generated Swift code.
  public let syntheticImportedModuleNames: Set<String>

  private var knownTypeToNominal: [SwiftKnownTypeDeclKind: SwiftNominalTypeDeclaration] = [:]
  private var prioritySortedImportedModules: [SwiftModuleSymbolTable] {
    // Ordering with source of symbols preference:
    // - main-source-of-symbols modules come first (alphabetical among themselves),
    // - then the rest (alphabetical).
    importedModules.values.sorted(by: { lhs, rhs in
      let lhsIsMain = lhs.alternativeModules?.isMainSourceOfSymbols ?? false
      let rhsIsMain = rhs.alternativeModules?.isMainSourceOfSymbols ?? false
      if lhsIsMain != rhsIsMain { return lhsIsMain }
      return lhs.moduleName < rhs.moduleName
    })
  }

  public init(
    parsedModule: SwiftModuleSymbolTable,
    importedModules: [String: SwiftModuleSymbolTable],
    syntheticImportedModuleNames: Set<String> = []
  ) {
    self.parsedModule = parsedModule
    self.importedModules = importedModules
    self.syntheticImportedModuleNames = syntheticImportedModuleNames
  }

  public func isModuleName(_ name: String) -> Bool {
    if name == moduleName {
      return true
    }
    return importedModules.keys.contains(name)
  }
}

extension SwiftSymbolTable {
  package static func setup(
    moduleName: String,
    _ inputFiles: some Collection<SwiftInputFile>,
    additionalInputFiles: [SwiftInputFile] = [],
    config: Configuration?,
    sourceDependencies: SourceDependencies,
    buildConfig: any BuildConfiguration = .swiftExtractDefault,
    log: Logger? = nil,
  ) -> SwiftSymbolTable {

    // Prepare imported modules.
    // FIXME: Support arbitrary dependencies.
    var modules: Set<ImportedSwiftModule> = []
    for inputFile in inputFiles {
      let importedModules = importingModules(sourceFile: inputFile.syntax)
      modules.formUnion(importedModules)
    }
    var importedModules: [String: SwiftModuleSymbolTable] = [:]
    importedModules[SwiftKnownModule.swift.name] = SwiftKnownModule.swift.symbolTable
    for module in modules {
      // We don't need duplicates of symbols, first known definition is enough to parse module
      // e.g Data from FoundationEssentials and Foundation collide and lead to different results due to random order of keys in Swift's Dictionary
      // guard module.isMainSourceOfSymbols || !importedModules.contains(where: { $0.value.isAlternative(for: String)}) else { continue }

      if importedModules[module.name] == nil,
        let knownModule = SwiftKnownModule(rawValue: module.name)
      {
        importedModules[module.name] = knownModule.symbolTable
      }
    }

    for dependencyModuleName in sourceDependencies.swiftModuleNames {
      // The module may already have been loaded as a known/built-in module
      // (e.g. Swift, Foundation) above
      guard importedModules[dependencyModuleName] == nil else {
        continue
      }
      let dependencyInputs =
        sourceDependencies.swiftModuleInputs[dependencyModuleName]
        ?? sourceDependencies.syntheticStubInputs[dependencyModuleName]
        ?? []
      // TODO: build a `dependencyImportedModules` dict by scanning the dep's
      // own source files with `importingModules(sourceFile:)`, instead of
      // reusing the primary's `importedModules`. The current set is too broad
      // (it can shadow names) and too narrow (it misses modules the dep
      // imports but the primary doesn't).
      var dependencyModuleBuilder = SwiftParsedModuleSymbolTableBuilder(
        moduleName: dependencyModuleName,
        importedModules: importedModules,
        buildConfig: buildConfig,
      )
      for input in dependencyInputs {
        dependencyModuleBuilder.handle(sourceFile: input.syntax, sourceFilePath: input.path)
      }
      let dependencyModule = dependencyModuleBuilder.finalize()
      importedModules[dependencyModuleName] = dependencyModule
      log?.info(
        "Loaded dependency module '\(dependencyModuleName)' from \(dependencyInputs.count) source(s); top-level types [\(dependencyModule.topLevelTypes.count)]: \(dependencyModule.topLevelTypes.keys.sorted())"
      )
    }

    // Load stub type declarations for imported modules from config.
    // This enables types from external modules (e.g. extension targets) to be
    // resolved in the symbol table without scanning their actual source.
    if let stubs = config?.importedModuleStubs {
      for (stubModuleName, declarations) in stubs {
        if importedModules[stubModuleName] == nil {
          let source = declarations.joined(separator: "\n")
          let sourceFile = Parser.parse(source: source)
          var stubBuilder = SwiftParsedModuleSymbolTableBuilder(
            moduleName: stubModuleName,
            importedModules: importedModules,
            buildConfig: buildConfig,
          )
          stubBuilder.handle(sourceFile: sourceFile, sourceFilePath: "\(stubModuleName)_stub.swift")
          let stubModule = stubBuilder.finalize()
          importedModules[stubModuleName] = stubModule
          log?.info("Loaded module stub for '\(stubModuleName)' with \(declarations.count) declaration(s), top-level types: \(stubModule.topLevelTypes.keys.sorted())")
        } else {
          log?.info("Module '\(stubModuleName)' already known, skipping stub")
        }
      }
    } else {
      log?.debug("No importedModuleStubs in config")
    }

    // FIXME: Support granular lookup context (file, type context).

    var builder = SwiftParsedModuleSymbolTableBuilder(
      moduleName: moduleName,
      importedModules: importedModules,
      buildConfig: buildConfig,
      log: log,
    )
    // First, register top-level and nested nominal types to the symbol table.
    for sourceFile in inputFiles {
      builder.handle(sourceFile: sourceFile.syntax, sourceFilePath: sourceFile.path)
    }
    for sourceFile in additionalInputFiles {
      builder.handle(sourceFile: sourceFile.syntax, sourceFilePath: sourceFile.path)
    }
    let parsedModule = builder.finalize()
    return SwiftSymbolTable(
      parsedModule: parsedModule,
      importedModules: importedModules,
      syntheticImportedModuleNames: sourceDependencies.syntheticModuleNames,
    )
  }
}

extension SwiftSymbolTable: SwiftSymbolTableProtocol {
  public var moduleName: String { parsedModule.moduleName }

  /// Look for a top-level nominal type with the given name. This should only
  /// return nominal types within this module.
  public func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration? {
    if let parsedResult = parsedModule.lookupTopLevelNominalType(name) {
      return parsedResult
    }

    for importedModule in prioritySortedImportedModules {
      if let result = importedModule.lookupTopLevelNominalType(name) {
        return result
      }
    }

    return nil
  }

  /// Look for a top-level nominal type in a specific module by name
  public func lookupTopLevelNominalType(_ name: String, inModule moduleName: String) -> SwiftNominalTypeDeclaration? {
    if moduleName == self.moduleName {
      return parsedModule.lookupTopLevelNominalType(name)
    }
    return importedModules[moduleName]?.lookupTopLevelNominalType(name)
  }

  /// Look for a top-level typealias with the given name.
  public func lookupTopLevelTypealias(_ name: String) -> SwiftTypeAliasDeclaration? {
    if let parsedResult = parsedModule.lookupTopLevelTypealias(name) {
      return parsedResult
    }

    for importedModule in prioritySortedImportedModules {
      if let result = importedModule.lookupTopLevelTypealias(name) {
        return result
      }
    }

    return nil
  }

  // Look for a nested type with the given name.
  public func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration? {
    if let parsedResult = parsedModule.lookupNestedType(name, parent: parent) {
      return parsedResult
    }

    for importedModule in importedModules.values {
      if let result = importedModule.lookupNestedType(name, parent: parent) {
        return result
      }
    }

    return nil
  }

  // Look for a nested typealias with the given name.
  public func lookupNestedTypealias(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftTypeAliasDeclaration? {
    if let parsedResult = parsedModule.lookupNestedTypealias(name, parent: parent) {
      return parsedResult
    }

    for importedModule in importedModules.values {
      if let result = importedModule.lookupNestedTypealias(name, parent: parent) {
        return result
      }
    }

    return nil
  }
}

extension SwiftSymbolTable {
  /// Map 'SwiftKnownTypeDeclKind' to the declaration.
  public subscript(knownType: SwiftKnownTypeDeclKind) -> SwiftNominalTypeDeclaration! {
    if let known = knownTypeToNominal[knownType] {
      return known
    }

    let (module, name) = knownType.moduleAndName
    guard let moduleTable = importedModules[module] else {
      return nil
    }

    let found = moduleTable.lookupTopLevelNominalType(name)
    knownTypeToNominal[knownType] = found
    return found
  }
}
