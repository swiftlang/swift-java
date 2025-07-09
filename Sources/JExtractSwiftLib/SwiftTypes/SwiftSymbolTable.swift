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

import SwiftSyntax

package protocol SwiftSymbolTableProtocol {
  /// The module name that this symbol table describes.
  var moduleName: String { get }

  /// Look for a top-level nominal type with the given name. This should only
  /// return nominal types within this module.
  func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration?

  // Look for a nested type with the given name.
  func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration?
}

extension SwiftSymbolTableProtocol {
  /// Look for a type
  package func lookupType(_ name: String, parent: SwiftNominalTypeDeclaration?) -> SwiftNominalTypeDeclaration? {
    if let parent {
      return lookupNestedType(name, parent: parent)
    }

    return lookupTopLevelNominalType(name)
  }
}

package class SwiftSymbolTable {
  let importedModules: [String: SwiftModuleSymbolTable]
  let parsedModule:SwiftModuleSymbolTable

  private var knownTypeToNominal: [SwiftKnownTypeDeclKind: SwiftNominalTypeDeclaration] = [:]

  init(parsedModule: SwiftModuleSymbolTable, importedModules: [String: SwiftModuleSymbolTable]) {
    self.parsedModule = parsedModule
    self.importedModules = importedModules
  }
}

extension SwiftSymbolTable {
  package static func setup(
    moduleName: String,
    _ sourceFiles: some Collection<SourceFileSyntax>,
    log: Logger
  ) -> SwiftSymbolTable {

    // Prepare imported modules.
    // FIXME: Support arbitrary dependencies.
    var moduleNames: Set<String> = []
    for sourceFile in sourceFiles {
      moduleNames.formUnion(importingModuleNames(sourceFile: sourceFile))
    }
    var importedModules: [String: SwiftModuleSymbolTable] = [:]
    importedModules[SwiftKnownModule.swift.name] = SwiftKnownModule.swift.symbolTable
    for moduleName in moduleNames.sorted() {
      if
        importedModules[moduleName] == nil,
        let knownModule = SwiftKnownModule(rawValue: moduleName)
      {
        importedModules[moduleName] = knownModule.symbolTable
      }
    }

    // FIXME: Support granular lookup context (file, type context).

    var builder = SwiftParsedModuleSymbolTableBuilder(moduleName: moduleName, importedModules: importedModules, log: log)
    // First, register top-level and nested nominal types to the symbol table.
    for sourceFile in sourceFiles {
      builder.handle(sourceFile: sourceFile)
    }
    let parsedModule = builder.finalize()
    return SwiftSymbolTable(parsedModule: parsedModule, importedModules: importedModules)
  }
}

extension SwiftSymbolTable: SwiftSymbolTableProtocol {
  package var moduleName: String { parsedModule.moduleName }

  /// Look for a top-level nominal type with the given name. This should only
  /// return nominal types within this module.
  package func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration? {
    if let parsedResult = parsedModule.lookupTopLevelNominalType(name) {
      return parsedResult
    }

    for importedModule in importedModules.values {
      if let result = importedModule.lookupTopLevelNominalType(name) {
        return result
      }
    }
    
    // FIXME: Implement module qualified name lookups. E.g. 'Swift.String'

    return nil
  }

  // Look for a nested type with the given name.
  package func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration? {
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
}

extension SwiftSymbolTable {
  /// Map 'SwiftKnownTypeDeclKind' to the declaration.
  subscript(knownType: SwiftKnownTypeDeclKind) -> SwiftNominalTypeDeclaration! {
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
