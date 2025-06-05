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

struct SwiftParsedModuleSymbolTable {
  var symbolTable: SwiftModuleSymbolTable

  /// The nominal type declarations, indexed by the nominal type declaration syntax node.
  var nominalTypeDeclarations: [SyntaxIdentifier: SwiftNominalTypeDeclaration] = [:]

  /// Mapping from the nominal type declarations in this module back to the syntax
  /// node. This is the reverse mapping of 'nominalTypeDeclarations'.
  var nominalTypeSyntaxNodes: [SwiftNominalTypeDeclaration: NominalTypeDeclSyntaxNode] = [:]

  init(moduleName: String) {
    symbolTable = .init(moduleName: moduleName)
  }
}

extension SwiftParsedModuleSymbolTable: SwiftSymbolTableProtocol {
  var moduleName: String {
    symbolTable.moduleName
  }
  
  func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration? {
    symbolTable.lookupTopLevelNominalType(name)
  }
  
  func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration? {
    symbolTable.lookupNestedType(name, parent: parent)
  }
}

extension SwiftParsedModuleSymbolTable {
  /// Look up a nominal type declaration based on its syntax node.
  func lookup(_ node: NominalTypeDeclSyntaxNode) -> SwiftNominalTypeDeclaration? {
    nominalTypeDeclarations[node.id]
  }

  /// Add a nominal type declaration and all of the nested types within it to the symbol
  /// table.
  @discardableResult
  mutating func addNominalTypeDeclaration(
    _ node: NominalTypeDeclSyntaxNode,
    parent: SwiftNominalTypeDeclaration?
  ) -> SwiftNominalTypeDeclaration {
    // If we have already recorded this nominal type declaration, we're done.
    if let existingNominal = nominalTypeDeclarations[node.id] {
      return existingNominal
    }

    // Otherwise, create the nominal type declaration.
    let nominalTypeDecl = SwiftNominalTypeDeclaration(
      moduleName: moduleName,
      parent: parent,
      node: node
    )

    // Ensure that we can find this nominal type declaration again based on the syntax
    // node, and vice versa.
    nominalTypeDeclarations[node.id] = nominalTypeDecl
    nominalTypeSyntaxNodes[nominalTypeDecl] = node

    if let parent {
      // For nested types, make them discoverable from the parent type.
      symbolTable.nestedTypes[parent, default: [:]][node.name.text] = nominalTypeDecl
    } else {
      // For top-level types, make them discoverable by name.
      symbolTable.topLevelTypes[node.name.text] = nominalTypeDecl
    }

    // Find any nested types within this nominal type and add them.
    for member in node.memberBlock.members {
      if let nominalMember = member.decl.asNominal {
        addNominalTypeDeclaration(nominalMember, parent: nominalTypeDecl)
      }
    }

    return nominalTypeDecl
  }

  /// Add any nested types within the given extension (with known extended nominal type
  /// declaration) to the symbol table.
  mutating func addExtension(
    _ extensionNode: ExtensionDeclSyntax,
    extending nominalTypeDecl: SwiftNominalTypeDeclaration
  ) {
    // Find any nested types within this extension and add them.
    for member in extensionNode.memberBlock.members {
      if let nominalMember = member.decl.asNominal {
        addNominalTypeDeclaration(nominalMember, parent: nominalTypeDecl)
      }
    }
  }
}

extension DeclSyntaxProtocol {
  var asNominal: NominalTypeDeclSyntaxNode? {
    switch DeclSyntax(self).as(DeclSyntaxEnum.self) {
    case .actorDecl(let actorDecl): actorDecl
    case .classDecl(let classDecl): classDecl
    case .enumDecl(let enumDecl): enumDecl
    case .protocolDecl(let protocolDecl): protocolDecl
    case .structDecl(let structDecl): structDecl
    default: nil
    }
  }
}
