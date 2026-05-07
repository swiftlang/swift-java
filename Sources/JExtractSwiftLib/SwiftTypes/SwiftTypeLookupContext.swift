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

@_spi(Experimental) import SwiftLexicalLookup
import SwiftSyntax

/// Type lookup manager.
/// All type lookups should be done via this instance. This caches the
/// association of `Syntax.ID` to `SwiftTypeDeclaration`, and guarantees that
/// there's only one `SwiftTypeDeclaration` per declaration `Syntax`.
class SwiftTypeLookupContext {
  var symbolTable: SwiftSymbolTable

  private var typeDecls: [Syntax.ID: SwiftTypeDeclaration] = [:]

  /// Set of typealias syntax ids currently being resolved, to break
  /// cycles like `typealias A = B; typealias B = A`.
  private var resolvingAliases: Set<Syntax.ID> = []

  init(symbolTable: SwiftSymbolTable) {
    self.symbolTable = symbolTable
  }

  /// Perform module-qualified type lookup in a specific module
  ///
  /// - Parameters:
  ///   - name: name to lookup
  ///   - moduleName: the module to look in
  func moduleQualifiedLookup(name: String, in moduleName: String) -> SwiftTypeDeclaration? {
    symbolTable.lookupTopLevelNominalType(name, inModule: moduleName)
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
        if let typeDecl = try typeDeclaration(for: scopeNode, sourceFilePath: "FIXME.swift") { // FIXME: no path here // implement some node -> file
          guard let nominalDecl = typeDecl as? SwiftNominalTypeDeclaration else {
            // Member lookup on a non-nominal (e.g. a typealias) is not supported here.
            continue
          }
          if let found = symbolTable.lookupNestedType(name.name, parent: nominalDecl) {
            return found
          }
          if let found = symbolTable.lookupNestedTypealias(name.name, parent: nominalDecl) {
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

    // maybe it's a typealias, can we resolve it to a known type?
    if let nominal = symbolTable.lookupTopLevelNominalType(name.name) {
      return nominal
    }
    // Fallback to global symbol table lookup.
    return symbolTable.lookupTopLevelTypealias(name.name)
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
      typeDecl = SwiftGenericParameterDeclaration(
        sourceFilePath: sourceFilePath,
        moduleName: symbolTable.moduleName,
        node: node
      )
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
      // For extensions, we need to resolve the extended type to find the
      // actual nominal type declaration. The extended type might be a simple
      // identifier (e.g. `extension Foo`) or a member type
      // (e.g. `extension P256._ARCV1`).

      if case .identifierType(let id) = Syntax(node.extendedType).as(SyntaxEnum.self),
        let lookupResult = try unqualifiedLookup(name: Identifier(id.name)!, from: node)
      {
        typeDecl = lookupResult
      } else {
        // For member types (e.g. P256._ARCV1), resolve through SwiftType
        let swiftType = try SwiftType(node.extendedType, lookupContext: self)
        guard let nominalDecl = swiftType.asNominalTypeDeclaration else {
          throw TypeLookupError.notType(Syntax(node))
        }
        typeDecl = nominalDecl
      }
    case .typeAliasDecl(let node):
      typeDecl = SwiftTypeAliasDeclaration(
        sourceFilePath: sourceFilePath,
        moduleName: symbolTable.moduleName,
        node: node
      )
    case .associatedTypeDecl:
      fatalError("associatedtype not implemented")
    default:
      throw TypeLookupError.notType(Syntax(node))
    }

    typeDecls[node.id] = typeDecl
    return typeDecl
  }

  /// Create a nominal type declaration instance for the specified syntax node.
  private func nominalTypeDeclaration(
    for node: NominalTypeDeclSyntaxNode,
    sourceFilePath: String
  ) throws -> SwiftNominalTypeDeclaration {

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
        return
          (try typeDeclaration(for: parentDecl, sourceFilePath: "FIXME_NO_SOURCE_FILE.swift")
          as! SwiftNominalTypeDeclaration) // FIXME: need to get the source file of the parent
      default:
        node = parentDecl
        continue
      }
    }
    return nil
  }

  /// Resolve a typealias to the `SwiftType` of its right-hand side.
  func resolve(typeAlias decl: SwiftTypeAliasDeclaration) throws -> SwiftType {
    let id = decl.syntax.id
    guard !resolvingAliases.contains(id) else {
      throw TypeTranslationError.unimplementedType(TypeSyntax(decl.syntax.initializer.value))
    }
    resolvingAliases.insert(id)
    defer { resolvingAliases.remove(id) }
    return try SwiftType(decl.syntax.initializer.value, lookupContext: self)
  }
}

enum TypeLookupError: Error {
  case notType(Syntax)
}
