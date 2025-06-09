//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import SwiftParser
import SwiftSyntax

final class Swift2JavaVisitor: SyntaxVisitor {
  let translator: Swift2JavaTranslator

  /// The Swift module we're visiting declarations in
  let moduleName: String

  /// The target java package we are going to generate types into eventually,
  /// store this along with type names as we import them.
  let targetJavaPackage: String

  /// Type context stack associated with the syntax.
  var typeContext: [(syntaxID: Syntax.ID, type: ImportedNominalType)] = []

  /// Innermost type context.
  var currentType: ImportedNominalType? { typeContext.last?.type }

  var currentSwiftType: SwiftType? {
    guard let currentType else { return nil }
    return .nominal(SwiftNominalType(nominalTypeDecl: currentType.swiftNominal))
  }

  /// The current type name as a nested name like A.B.C.
  var currentTypeName: String? { self.currentType?.swiftNominal.qualifiedName }

  var log: Logger { translator.log }

  init(moduleName: String, targetJavaPackage: String, translator: Swift2JavaTranslator) {
    self.moduleName = moduleName
    self.targetJavaPackage = targetJavaPackage
    self.translator = translator

    super.init(viewMode: .all)
  }

  /// Push specified type to the type context associated with the syntax.
  func pushTypeContext(syntax: some SyntaxProtocol, importedNominal: ImportedNominalType) {
    typeContext.append((syntax.id, importedNominal))
  }

  /// Pop type context if the current context is associated with the syntax.
  func popTypeContext(syntax: some SyntaxProtocol) -> Bool {
    if typeContext.last?.syntaxID == syntax.id {
      typeContext.removeLast()
      return true
    } else {
      return false
    }
  }

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    log.debug("Visit \(node.kind): '\(node.qualifiedNameForDebug)'")
    guard let importedNominalType = translator.importedNominalType(node, parent: self.currentType) else {
      return .skipChildren
    }

    self.pushTypeContext(syntax: node, importedNominal: importedNominalType)
    return .visitChildren
  }

  override func visitPost(_ node: ClassDeclSyntax) {
    if self.popTypeContext(syntax: node) {
      log.debug("Completed import: \(node.kind) \(node.name)")
    }
  }

  override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
    log.debug("Visit \(node.kind): \(node.qualifiedNameForDebug)")
    guard let importedNominalType = translator.importedNominalType(node, parent: self.currentType) else {
      return .skipChildren
    }

    self.pushTypeContext(syntax: node, importedNominal: importedNominalType)
    return .visitChildren
  }

  override func visitPost(_ node: StructDeclSyntax) {
    if self.popTypeContext(syntax: node) {
      log.debug("Completed import: \(node.kind) \(node.qualifiedNameForDebug)")
    }
  }

  override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
    // Resolve the extended type of the extension as an imported nominal, and
    // recurse if we found it.
    guard let importedNominalType = translator.importedNominalType(node.extendedType) else {
      return .skipChildren
    }

    self.pushTypeContext(syntax: node, importedNominal: importedNominalType)
    return .visitChildren
  }

  override func visitPost(_ node: ExtensionDeclSyntax) {
    if self.popTypeContext(syntax: node) {
      log.debug("Completed import: \(node.kind) \(node.qualifiedNameForDebug)")
    }
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard node.shouldImport(log: log) else {
      return .skipChildren
    }

    self.log.debug("Import function: '\(node.qualifiedNameForDebug)'")

    let signature: SwiftFunctionSignature
    do {
      signature = try SwiftFunctionSignature(
        node,
        enclosingType: self.currentSwiftType,
        symbolTable: self.translator.symbolTable
      )
    } catch {
      self.log.debug("Failed to import: '\(node.qualifiedNameForDebug)'; \(error)")
      return .skipChildren
    }

    let imported = ImportedFunc(
      module: translator.swiftModuleName,
      swiftDecl: node,
      name: node.name.text,
      apiKind: .function,
      functionSignature: signature
    )

    log.debug("Record imported method \(node.qualifiedNameForDebug)")
    if let currentType {
      currentType.methods.append(imported)
    } else {
      translator.importedGlobalFuncs.append(imported)
    }

    return .skipChildren
  }

  override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
    guard node.shouldImport(log: log) else {
      return .skipChildren
    }

    guard let binding = node.bindings.first else {
      return .skipChildren
    }

    let varName = "\(binding.pattern.trimmed)"

    self.log.debug("Import variable: \(node.kind) '\(node.qualifiedNameForDebug)'")

    func importAccessor(kind: SwiftAPIKind) throws {
      let signature = try SwiftFunctionSignature(
        node,
        isSet: kind == .setter,
        enclosingType: self.currentSwiftType,
        symbolTable: self.translator.symbolTable
      )

      let imported = ImportedFunc(
        module: translator.swiftModuleName,
        swiftDecl: node,
        name: varName,
        apiKind: kind,
        functionSignature: signature
      )
      
      log.debug("Record imported variable accessor \(kind == .getter ? "getter" : "setter"):\(node.qualifiedNameForDebug)")
      if let currentType {
        currentType.variables.append(imported)
      } else {
        translator.importedGlobalVariables.append(imported)
      }
    }

    do {
      let supportedAccessors = node.supportedAccessorKinds(binding: binding)
      if supportedAccessors.contains(.get) {
        try importAccessor(kind: .getter)
      }
      if supportedAccessors.contains(.set) {
        try importAccessor(kind: .setter)
      }
    } catch {
      self.log.debug("Failed to import: \(node.qualifiedNameForDebug); \(error)")
      return .skipChildren
    }

    return .skipChildren
  }

  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let currentType else {
      fatalError("Initializer must be within a current type, was: \(node)")
    }
    guard node.shouldImport(log: log) else {
      return .skipChildren
    }

    self.log.debug("Import initializer: \(node.kind) '\(node.qualifiedNameForDebug)'")

    let signature: SwiftFunctionSignature
    do {
      signature = try SwiftFunctionSignature(
        node,
        enclosingType: self.currentSwiftType,
        symbolTable: self.translator.symbolTable
      )
    } catch {
      self.log.debug("Failed to import: \(node.qualifiedNameForDebug); \(error)")
      return .skipChildren
    }
    let imported = ImportedFunc(
      module: translator.swiftModuleName,
      swiftDecl: node,
      name: "init",
      apiKind: .initializer,
      functionSignature: signature
    )

    currentType.initializers.append(imported)

    return .skipChildren
  }

  override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    return .skipChildren
  }
}

extension DeclSyntaxProtocol where Self: WithModifiersSyntax & WithAttributesSyntax {
  func shouldImport(log: Logger) -> Bool {
    guard accessControlModifiers.contains(where: { $0.isPublic }) else {
      log.trace("Skip import '\(self.qualifiedNameForDebug)': not public")
      return false
    }
    guard !attributes.contains(where: { $0.isJava }) else {
      log.trace("Skip import '\(self.qualifiedNameForDebug)': is Java")
      return false
    }

    if let node = self.as(InitializerDeclSyntax.self) {
      let isFailable = node.optionalMark != nil

      if isFailable {
        log.warning("Skip import '\(self.qualifiedNameForDebug)': failable initializer")
        return false
      }
    }

    return true
  }
}
