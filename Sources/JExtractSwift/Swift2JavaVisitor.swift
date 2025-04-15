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

  /// The current type name as a nested name like A.B.C.
  var currentTypeName: String? { self.currentType?.swiftTypeName }

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
    guard let importedNominalType = translator.importedNominalType(node) else {
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
    guard let importedNominalType = translator.importedNominalType(node) else {
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
    guard let nominal = translator.nominalResolution.extendedType(of: node),
      let importedNominalType = translator.importedNominalType(nominal)
    else {
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

    self.log.debug("Import function: \(node.kind) \(node.name)")

    let returnTy: TypeSyntax
    if let returnClause = node.signature.returnClause {
      returnTy = returnClause.type
    } else {
      returnTy = "Swift.Void"
    }

    let params: [ImportedParam]
    let javaResultType: TranslatedType
    do {
      params = try node.signature.parameterClause.parameters.map { param in
        // TODO: more robust parameter handling
        // TODO: More robust type handling
        ImportedParam(
          syntax: param,
          type: try cCompatibleType(for: param.type)
        )
      }

      javaResultType = try cCompatibleType(for: returnTy)
    } catch {
      self.log.info("Unable to import function \(node.name) - \(error)")
      return .skipChildren
    }

    let fullName = "\(node.name.text)"

    let funcDecl = ImportedFunc(
      module: self.translator.swiftModuleName,
      decl: node.trimmed,
      parent: currentTypeName.map { translator.importedTypes[$0] }??.translatedType,
      identifier: fullName,
      returnType: javaResultType,
      parameters: params
    )

    if let currentTypeName {
      log.debug("Record method in \(currentTypeName)")
      translator.importedTypes[currentTypeName]?.methods.append(funcDecl)
    } else {
      translator.importedGlobalFuncs.append(funcDecl)
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

    let fullName = "\(binding.pattern.trimmed)"

    // TODO: filter out kinds of variables we cannot import

    self.log.debug("Import variable: \(node.kind) '\(node.qualifiedNameForDebug)'")

    let returnTy: TypeSyntax
    if let typeAnnotation = binding.typeAnnotation {
      returnTy = typeAnnotation.type
    } else {
      returnTy = "Swift.Void"
    }

    let javaResultType: TranslatedType
    do {
      javaResultType = try cCompatibleType(for: returnTy)
    } catch {
      log.info("Unable to import variable '\(node.qualifiedNameForDebug)' - \(error)")
      return .skipChildren
    }

    var varDecl = ImportedVariable(
      module: self.translator.swiftModuleName,
      parentName: currentTypeName.map { translator.importedTypes[$0] }??.translatedType,
      identifier: fullName,
      returnType: javaResultType
    )
    varDecl.syntax = node.trimmed

    // Retrieve the mangled name, if available.
    if let mangledName = node.mangledNameFromComment {
      varDecl.swiftMangledName = mangledName
    }

    if let currentTypeName {
      log.debug("Record variable in \(currentTypeName)")
      translator.importedTypes[currentTypeName]!.variables.append(varDecl)
    } else {
      fatalError("Global variables are not supported yet: \(node.qualifiedNameForDebug)")
    }

    return .skipChildren
  }

  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let currentTypeName,
      let currentType = translator.importedTypes[currentTypeName]
    else {
      fatalError("Initializer must be within a current type, was: \(node)")
    }
    guard node.shouldImport(log: log) else {
      return .skipChildren
    }

    self.log.debug("Import initializer: \(node.kind) '\(node.qualifiedNameForDebug)'")
    let params: [ImportedParam]
    do {
      params = try node.signature.parameterClause.parameters.map { param in
        // TODO: more robust parameter handling
        // TODO: More robust type handling
        return ImportedParam(
          syntax: param,
          type: try cCompatibleType(for: param.type)
        )
      }
    } catch {
      self.log.info("Unable to import initializer due to \(error)")
      return .skipChildren
    }

    let initIdentifier =
      "init(\(String(params.flatMap { "\($0.effectiveName ?? "_"):" })))"

    var funcDecl = ImportedFunc(
      module: self.translator.swiftModuleName,
      decl: node.trimmed,
      parent: currentType.translatedType,
      identifier: initIdentifier,
      returnType: currentType.translatedType,
      parameters: params
    )
    funcDecl.isInit = true

    log.debug(
      "Record initializer method in \(currentType.javaType.description): \(funcDecl.identifier)")
    translator.importedTypes[currentTypeName]!.initializers.append(funcDecl)

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

private let mangledNameCommentPrefix = "MANGLED NAME: "

extension SyntaxProtocol {
  /// Look in the comment text prior to the node to find a mangled name
  /// identified by "// MANGLED NAME: ".
  var mangledNameFromComment: String? {
    for triviaPiece in leadingTrivia {
      guard case .lineComment(let comment) = triviaPiece,
        let matchRange = comment.range(of: mangledNameCommentPrefix)
      else {
        continue
      }

      return String(comment[matchRange.upperBound...])
    }

    return nil
  }
}
