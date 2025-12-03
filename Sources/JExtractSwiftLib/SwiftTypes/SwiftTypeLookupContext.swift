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

      case .lookForMembers(let scopeNode):
        if let nominalDecl = try typeDeclaration(for: scopeNode, sourceFilePath: "FIXME.swift") { // FIXME: no path here // implement some node -> file
          if let found = symbolTable.lookupNestedType(name.name, parent: nominalDecl as! SwiftNominalTypeDeclaration) {
            return found
          }
        }

      case .lookForGenericParameters(let extensionNode):
        // TODO: Implement
        _ = extensionNode
        break

      case .lookForImplicitClosureParameters:
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
        return try? typeDeclaration(for: identifiableSyntax, sourceFilePath: "FIXME_NO_PATH.swift") // FIXME: how to get path here?
      case .declaration(let namedDeclSyntax):
        return try? typeDeclaration(for: namedDeclSyntax, sourceFilePath: "FIXME_NO_PATH.swift") // FIXME: how to get path here?
      case .implicit(let implicitDecl):
        // TODO: Implement
        _ = implicitDecl
        break
      case .equivalentNames(let equivalentNames):
        // TODO: Implement
        _ = equivalentNames
      }
    }
    return nil
  }

  /// Returns the type declaration object associated with the `Syntax` node.
  /// If there's no declaration created, create an instance on demand, and cache it.
  func typeDeclaration(for node: some SyntaxProtocol, sourceFilePath: String) throws -> SwiftTypeDeclaration? {
    if let found = typeDecls[node.id] {
      return found
    }

    let typeDecl: SwiftTypeDeclaration
    switch Syntax(node).as(SyntaxEnum.self) {
    case .genericParameter(let node):
      typeDecl = SwiftGenericParameterDeclaration(sourceFilePath: sourceFilePath, moduleName: symbolTable.moduleName, node: node)
    case .classDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node, sourceFilePath: sourceFilePath)
    case .actorDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node, sourceFilePath: sourceFilePath)
    case .structDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node, sourceFilePath: sourceFilePath)
    case .enumDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node, sourceFilePath: sourceFilePath)
    case .protocolDecl(let node):
      typeDecl = try nominalTypeDeclaration(for: node, sourceFilePath: sourceFilePath)
    case .extensionDecl(let node):
      // For extensions, we have to perform a unqualified lookup,
      // as the extentedType is just the identifier of the type.

      guard case .identifierType(let id) = Syntax(node.extendedType).as(SyntaxEnum.self),
            let lookupResult = try unqualifiedLookup(name: Identifier(id.name)!, from: node)
      else {
        throw TypeLookupError.notType(Syntax(node))
      }

      typeDecl = lookupResult
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
  private func nominalTypeDeclaration(for node: NominalTypeDeclSyntaxNode, sourceFilePath: String) throws -> SwiftNominalTypeDeclaration {

    if let symbolTableDeclaration = self.symbolTable.lookupType(
      node.name.text,
      parent: try parentTypeDecl(for: node)
    ) {
      return symbolTableDeclaration
    }

    return SwiftNominalTypeDeclaration(
      sourceFilePath: sourceFilePath,
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
        return (try typeDeclaration(for: parentDecl, sourceFilePath: "FIXME_NO_SOURCE_FILE.swift") as! SwiftNominalTypeDeclaration) // FIXME: need to get the source file of the parent
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
