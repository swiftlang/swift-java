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
@_spi(Experimental) import SwiftLexicalLookup

/// Unqualified type lookup manager.
/// All unqualified lookup should be done via this instance. This caches the
/// association of `Syntax.ID` to `SwiftTypeDeclaration`, and guarantees that
/// there's only one `SwiftTypeDeclaration` per declaration `Syntax`.
class SwiftTypeLookupContext {
  var symbolTable: SwiftSymbolTable

  private var typeDecls: [Syntax.ID: SwiftTypeDeclaration] = [:]

  init(symbolTable: SwiftSymbolTable) {
    self.symbolTable = symbolTable
  }

  /// Perform unqualified type lookup.
  ///
  /// - Parameters:
  ///   - name: name to lookup
  ///   - node: `Syntax` node the lookup happened
  func unqualifiedLookup(name: Identifier, from node: some SyntaxProtocol) throws -> SwiftTypeDeclaration? {

    for result in node.lookup(name) {
      switch result {
      case .fromScope(_, let names):
        if !names.isEmpty {
          return typeDeclaration(for: names)
        }

      case .fromFileScope(_, let names):
        if !names.isEmpty {
          return typeDeclaration(for: names)
        }

      case .lookInMembers(let scopeNode):
        if let nominalDecl = try typeDeclaration(for: scopeNode) {
          if let found = symbolTable.lookupNestedType(name.name, parent: nominalDecl as! SwiftNominalTypeDeclaration) {
            return found
          }
        }

      case .lookInGenericParametersOfExtendedType(let extensionNode):
        // TODO: Implement
        _ = extensionNode
        break

      case .mightIntroduceDollarIdentifiers:
        // Dollar identifier can't be a type, ignore.
        break
      }
    }

    // Fallback to global symbol table lookup.
    return symbolTable.lookupTopLevelNominalType(name.name)
  }

  /// Find the first type declaration in the `LookupName` results.
  private func typeDeclaration(for names: [LookupName]) -> SwiftTypeDeclaration? {
    for name in names {
      switch name {
      case .identifier(let identifiableSyntax, _):
        return try? typeDeclaration(for: identifiableSyntax)
      case .declaration(let namedDeclSyntax):
        return try? typeDeclaration(for: namedDeclSyntax)
      case .implicit(let implicitDecl):
        // TODO: Implement
        _ = implicitDecl
        break
      case .dollarIdentifier:
        break
      }
    }
    return nil
  }

  /// Returns the type declaration object associated with the `Syntax` node.
  /// If there's no declaration created, create an instance on demand, and cache it.
  func typeDeclaration(for node: some SyntaxProtocol) throws -> SwiftTypeDeclaration? {
    if let found = typeDecls[node.id] {
      return found
    }

    let typeDecl: SwiftTypeDeclaration
    switch Syntax(node).as(SyntaxEnum.self) {
    case .genericParameter(let node):
      typeDecl = SwiftGenericParameterDeclaration(moduleName: symbolTable.moduleName, node: node)
    case .classDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node)
    case .actorDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node)
    case .structDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node)
    case .enumDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node)
    case .protocolDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node)
    case .typeAliasDecl:
      fatalError("typealias not implemented")
    case .associatedTypeDecl:
      fatalError("associatedtype not implemented")
    default:
      throw TypeLookupError.notType(Syntax(node))
    }

    typeDecls[node.id] = typeDecl
    return typeDecl
  }

  /// Create a nominal type declaration instance for the specified syntax node.
  private func nominalTypeDeclaration(for node: NominalTypeDeclSyntaxNode) throws -> SwiftNominalTypeDeclaration {
    SwiftNominalTypeDeclaration(
      moduleName: self.symbolTable.moduleName,
      parent: try parentTypeDecl(for: node),
      node: node
    )
  }

  /// Find a parent nominal type declaration of the specified syntax node.
  private func parentTypeDecl(for node: some DeclSyntaxProtocol) throws -> SwiftNominalTypeDeclaration? {
    var node: DeclSyntax = DeclSyntax(node)
    while let parentDecl = node.ancestorDecl {
      switch parentDecl.as(DeclSyntaxEnum.self) {
      case .structDecl, .classDecl, .actorDecl, .enumDecl, .protocolDecl:
        return (try typeDeclaration(for: parentDecl) as! SwiftNominalTypeDeclaration)
      default:
        node = parentDecl
        continue
      }
    }
    return nil
  }
}

enum TypeLookupError: Error {
  case notType(Syntax)
}
