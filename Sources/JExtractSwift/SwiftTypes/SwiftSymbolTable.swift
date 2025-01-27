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

protocol SwiftSymbolTableProtocol {
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
  func lookupType(_ name: String, parent: SwiftNominalTypeDeclaration?) -> SwiftNominalTypeDeclaration? {
    if let parent {
      return lookupNestedType(name, parent: parent)
    }

    return lookupTopLevelNominalType(name)
  }
}

class SwiftSymbolTable {
  var importedModules: [SwiftModuleSymbolTable] = []
  var parsedModule: SwiftParsedModuleSymbolTable

  init(parsedModuleName: String) {
    self.parsedModule = SwiftParsedModuleSymbolTable(moduleName: parsedModuleName)
  }

  func addImportedModule(symbolTable: SwiftModuleSymbolTable) {
    importedModules.append(symbolTable)
  }

  func addTopLevelNominalTypeDeclarations(_ sourceFile: SourceFileSyntax) {
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

  func addExtensions(
    _ sourceFile: SourceFileSyntax,
    nominalResolution: NominalTypeResolution
  ) {
    // Find extensions.
    for statement in sourceFile.statements {
      // We only care about declarations.
      guard case .decl(let decl) = statement.item,
          let extNode = decl.as(ExtensionDeclSyntax.self),
            let extendedTypeNode = nominalResolution.extendedType(of: extNode),
            let extendedTypeDecl = parsedModule.nominalTypeDeclarations[extendedTypeNode.id] else {
        continue
      }

      parsedModule.addExtension(extNode, extending: extendedTypeDecl)
    }
  }
}

extension SwiftSymbolTable: SwiftSymbolTableProtocol {
  var moduleName: String { parsedModule.moduleName }

  /// Look for a top-level nominal type with the given name. This should only
  /// return nominal types within this module.
  func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration? {
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
  func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration? {
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
