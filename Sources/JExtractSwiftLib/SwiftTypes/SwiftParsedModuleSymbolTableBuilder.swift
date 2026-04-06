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

struct SwiftParsedModuleSymbolTableBuilder {
  let log: Logger?

  /// The symbol table being built.
  var symbolTable: SwiftModuleSymbolTable

  /// Imported modules to resolve type syntax.
  let importedModules: [String: SwiftModuleSymbolTable]

  /// Extension decls their extended type hasn't been resolved.
  var unresolvedExtensions: [ExtensionDeclSyntax]

  init(
    moduleName: String,
    requiredAvailablityOfModuleWithName: String? = nil,
    alternativeModules: SwiftModuleSymbolTable.AlternativeModuleNamesData? = nil,
    importedModules: [String: SwiftModuleSymbolTable],
    log: Logger? = nil
  ) {
    self.log = log
    self.symbolTable = .init(
      moduleName: moduleName,
      requiredAvailablityOfModuleWithName: requiredAvailablityOfModuleWithName,
      alternativeModules: alternativeModules
    )
    self.importedModules = importedModules
    self.unresolvedExtensions = []
  }

  var moduleName: String {
    symbolTable.moduleName
  }
}

extension SwiftParsedModuleSymbolTableBuilder {

  mutating func handle(
    sourceFile: SourceFileSyntax,
    sourceFilePath: String
  ) {
    // Find top-level type declarations.
    for statement in sourceFile.statements {
      // We only care about declarations.
      guard case .decl(let decl) = statement.item else {
        continue
      }

      if let nominalTypeNode = decl.asNominal {
        self.handle(sourceFilePath: sourceFilePath, nominalTypeDecl: nominalTypeNode, parent: nil)
      }
      if let extensionNode = decl.as(ExtensionDeclSyntax.self) {
        self.handle(extensionDecl: extensionNode, sourceFilePath: sourceFilePath)
      }
    }
  }

  /// Add a nominal type declaration and all of the nested types within it to the symbol
  /// table.
  mutating func handle(
    sourceFilePath: String,
    nominalTypeDecl node: NominalTypeDeclSyntaxNode,
    parent: SwiftNominalTypeDeclaration?
  ) {
    // If we have already recorded a nominal type with the name in this module,
    // it's an invalid redeclaration.
    if let _ = symbolTable.lookupType(node.name.text, parent: parent) {
      log?.debug("Failed to add a decl into symbol table: redeclaration; " + node.nameForDebug)
      return
    }

    // Otherwise, create the nominal type declaration.
    let nominalTypeDecl = SwiftNominalTypeDeclaration(
      sourceFilePath: sourceFilePath,
      moduleName: moduleName,
      parent: parent,
      node: node
    )

    if let parent {
      // For nested types, make them discoverable from the parent type.
      symbolTable.nestedTypes[parent, default: [:]][nominalTypeDecl.name] = nominalTypeDecl
    } else {
      // For top-level types, make them discoverable by name.
      symbolTable.topLevelTypes[nominalTypeDecl.name] = nominalTypeDecl
    }

    self.handle(sourceFilePath: sourceFilePath, memberBlock: node.memberBlock, parent: nominalTypeDecl)
  }

  mutating func handle(
    sourceFilePath: String,
    memberBlock node: MemberBlockSyntax,
    parent: SwiftNominalTypeDeclaration
  ) {
    for member in node.members {
      // Find any nested types within this nominal type and add them.
      if let nominalMember = member.decl.asNominal {
        self.handle(sourceFilePath: sourceFilePath, nominalTypeDecl: nominalMember, parent: parent)
      }
    }

  }

  mutating func handle(
    extensionDecl node: ExtensionDeclSyntax,
    sourceFilePath: String
  ) {
    if !self.tryHandle(extension: node, sourceFilePath: sourceFilePath) {
      self.unresolvedExtensions.append(node)
    }
  }

  /// Add any nested types within the given extension to the symbol table.
  /// If the extended nominal type can't be resolved, returns false.
  mutating func tryHandle(
    extension node: ExtensionDeclSyntax,
    sourceFilePath: String
  ) -> Bool {
    // Try to resolve the type referenced by this extension declaration.
    // If it fails, we'll try again later.
    let table = SwiftSymbolTable(
      parsedModule: symbolTable,
      importedModules: importedModules
    )
    let lookupContext = SwiftTypeLookupContext(symbolTable: table)
    guard let extendedType = try? SwiftType(node.extendedType, lookupContext: lookupContext) else {
      return false
    }
    guard let extendedNominal = extendedType.asNominalTypeDeclaration else {
      // Extending type was not a nominal type. Ignore it.
      return true
    }

    // Find any nested types within this extension and add them.
    self.handle(sourceFilePath: sourceFilePath, memberBlock: node.memberBlock, parent: extendedNominal)
    return true
  }

  /// Finalize the symbol table and return it.
  mutating func finalize() -> SwiftModuleSymbolTable {
    // Handle the unresolved extensions.
    // The work queue is required because, the extending type might be declared
    // in another extension that hasn't been processed. E.g.:
    //
    //   extension Outer.Inner { struct Deeper {} }
    //   extension Outer { struct Inner {} }
    //   struct Outer {}
    //
    while !unresolvedExtensions.isEmpty {
      var extensions = self.unresolvedExtensions
      extensions.removeAll(where: {
        self.tryHandle(extension: $0, sourceFilePath: "FIXME_MISSING_FILEPATH.swift") // FIXME: missing filepath here in finalize
      })

      // If we didn't resolve anything, we're done.
      if extensions.count == unresolvedExtensions.count {
        break
      }

      assert(extensions.count < unresolvedExtensions.count)
      self.unresolvedExtensions = extensions
    }

    return symbolTable
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
