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
  var importedModules: [SwiftModuleSymbolTable] = []
  var parsedModule: SwiftParsedModuleSymbolTable

  package init(parsedModuleName: String) {
    self.parsedModule = SwiftParsedModuleSymbolTable(moduleName: parsedModuleName)
  }

  func addImportedModule(symbolTable: SwiftModuleSymbolTable) {
    importedModules.append(symbolTable)
  }
}

extension SwiftSymbolTable {
  package func setup(_ sourceFiles: some Collection<SourceFileSyntax>) {
    // First, register top-level and nested nominal types to the symbol table.
    for sourceFile in sourceFiles {
      self.addNominalTypeDeclarations(sourceFile)
    }

    // Next bind the extensions.

    // The work queue is required because, the extending type might be declared
    // in another extension that hasn't been processed. E.g.:
    //
    //   extension Outer.Inner { struct Deeper {} }
    //   extension Outer { struct Inner {} }
    //   struct Outer {}
    //
    var unresolvedExtensions: [ExtensionDeclSyntax] = []
    for sourceFile in sourceFiles {
      // Find extensions.
      for statement in sourceFile.statements {
        // We only care about extensions at top-level.
        if case .decl(let decl) = statement.item, let extNode = decl.as(ExtensionDeclSyntax.self) {
          let resolved = handleExtension(extNode)
          if !resolved {
            unresolvedExtensions.append(extNode)
          }
        }
      }
    }

    while !unresolvedExtensions.isEmpty {
      let numExtensionsBefore = unresolvedExtensions.count
      unresolvedExtensions.removeAll(where: handleExtension(_:))

      // If we didn't resolve anything, we're done.
      if numExtensionsBefore == unresolvedExtensions.count {
        break
      }
      assert(numExtensionsBefore > unresolvedExtensions.count)
    }
  }

  private func addNominalTypeDeclarations(_ sourceFile: SourceFileSyntax) {
    // Find top-level nominal type declarations.
    for statement in sourceFile.statements {
      // We only care about declarations.
      guard case .decl(let decl) = statement.item,
          let nominalTypeNode = decl.asNominal else {
        continue
      }

      parsedModule.addNominalTypeDeclaration(nominalTypeNode, parent: nil)
    }
  }

  private func handleExtension(_ extensionDecl: ExtensionDeclSyntax) -> Bool {
    // Try to resolve the type referenced by this extension declaration.
    // If it fails, we'll try again later.
    guard let extendedType = try? SwiftType(extensionDecl.extendedType, symbolTable: self) else {
      return false
    }
    guard let extendedNominal = extendedType.asNominalTypeDeclaration else {
      // Extending type was not a nominal type. Ignore it.
      return true
    }

    // Register nested nominals in extensions to the symbol table.
    parsedModule.addExtension(extensionDecl, extending: extendedNominal)

    // We have successfully resolved the extended type. Record it.
    return true
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

    for importedModule in importedModules {
      if let result = importedModule.lookupTopLevelNominalType(name) {
        return result
      }
    }
    
    return nil
  }

  // Look for a nested type with the given name.
  package func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration? {
    if let parsedResult = parsedModule.lookupNestedType(name, parent: parent) {
      return parsedResult
    }

    for importedModule in importedModules {
      if let result = importedModule.lookupNestedType(name, parent: parent) {
        return result
      }
    }

    return nil
  }
}
