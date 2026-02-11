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
  let parsedModule: SwiftModuleSymbolTable

  private var knownTypeToNominal: [SwiftKnownTypeDeclKind: SwiftNominalTypeDeclaration] = [:]
  private var prioritySortedImportedModules: [SwiftModuleSymbolTable] {
    importedModules.values.sorted(by: {
      ($0.alternativeModules?.isMainSourceOfSymbols ?? false) && $0.moduleName < $1.moduleName
    })
  }

  init(parsedModule: SwiftModuleSymbolTable, importedModules: [String: SwiftModuleSymbolTable]) {
    self.parsedModule = parsedModule
    self.importedModules = importedModules
  }
}

extension SwiftSymbolTable {
  package static func setup(
    moduleName: String,
    _ inputFiles: some Collection<SwiftJavaInputFile>,
    log: Logger
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

    // FIXME: Support granular lookup context (file, type context).

    var builder = SwiftParsedModuleSymbolTableBuilder(
      moduleName: moduleName,
      importedModules: importedModules,
      log: log
    )
    // First, register top-level and nested nominal types to the symbol table.
    for sourceFile in inputFiles {
      builder.handle(sourceFile: sourceFile.syntax, sourceFilePath: sourceFile.path)
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

    for importedModule in prioritySortedImportedModules {
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

extension SwiftSymbolTable {
  func printImportedModules(_ printer: inout CodePrinter) {
    let mainSymbolSourceModules = Set(
      self.importedModules.values.filter { $0.alternativeModules?.isMainSourceOfSymbols ?? false }.map(\.moduleName)
    )

    for module in self.importedModules.keys.sorted() {
      guard module != "Swift" else {
        continue
      }

      guard let alternativeModules = self.importedModules[module]?.alternativeModules else {
        printer.print("import \(module)")
        continue
      }

      // Try to print only on main module from relation chain as it has every other module.
      guard
        !mainSymbolSourceModules.isDisjoint(with: alternativeModules.moduleNames)
          || alternativeModules.isMainSourceOfSymbols
      else {
        if !alternativeModules.isMainSourceOfSymbols {
          printer.print("import \(module)")
        }
        continue
      }

      var importGroups: [String: [String]] = [:]
      for name in alternativeModules.moduleNames {
        guard let otherModule = self.importedModules[name] else { continue }

        let groupKey = otherModule.requiredAvailablityOfModuleWithName ?? otherModule.moduleName
        importGroups[groupKey, default: []].append(otherModule.moduleName)
      }

      for (index, group) in importGroups.keys.sorted().enumerated() {
        if index > 0 && importGroups.keys.count > 1 {
          printer.print("#elseif canImport(\(group))")
        } else {
          printer.print("#if canImport(\(group))")
        }

        for groupModule in importGroups[group] ?? [] {
          printer.print("import \(groupModule)")
        }
      }

      if importGroups.keys.isEmpty {
        printer.print("import \(module)")
      } else {
        printer.print("#else")
        printer.print("import \(module)")
        printer.print("#endif")
      }
    }
    printer.println()
  }
}
