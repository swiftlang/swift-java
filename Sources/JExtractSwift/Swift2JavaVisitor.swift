//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
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

  var currentTypeName: String? = nil

  var log: Logger { translator.log }

  init(moduleName: String, targetJavaPackage: String, translator: Swift2JavaTranslator) {
    self.moduleName = moduleName
    self.targetJavaPackage = targetJavaPackage
    self.translator = translator

    super.init(viewMode: .all)
  }

  override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
    guard node.shouldImport(log: log) else {
      return .skipChildren
    }

    log.info("Import: \(node.kind) \(node.name)")
    let typeName = node.name.text
    currentTypeName = typeName
    translator.importedTypes[typeName] = ImportedNominalType(
      // TODO: support nested classes (parent name here)
      name: ImportedTypeName(
        swiftTypeName: typeName,
        javaType: .class(
          package: targetJavaPackage,
          name: typeName
        ),
        swiftMangledName: node.mangledNameFromComment
      ),
      kind: .class
    )

    return .visitChildren
  }

  override func visitPost(_ node: ClassDeclSyntax) {
    if currentTypeName != nil {
      log.info("Completed import: \(node.kind) \(node.name)")
      currentTypeName = nil
    }
  }

  override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
    guard node.shouldImport(log: log) else {
      return .skipChildren
    }

    self.log.info("Import function: \(node.kind) \(node.name)")

    // TODO: this must handle inout and other stuff, strip it off etc
    let returnTy: TypeSyntax
    if let returnClause = node.signature.returnClause {
      returnTy = returnClause.type
    } else {
      returnTy = "Swift.Void"
    }

    let params: [ImportedParam]
    let javaResultType: ImportedTypeName
    do {
      params = try node.signature.parameterClause.parameters.map { param in
        // TODO: more robust parameter handling
        // TODO: More robust type handling
        return ImportedParam(
          param: param,
          type: try mapTypeToJava(name: param.type)
        )
      }

      javaResultType = try mapTypeToJava(name: returnTy)
    } catch {
      self.log.info("Unable to import function \(node.name) - \(error)")
      return .skipChildren
    }

    let argumentLabels = node.signature.parameterClause.parameters.map { param in
      param.firstName.identifier?.name ?? "_"
    }
    let argumentLabelsStr = String(argumentLabels.flatMap { label in
      label + ":"
    })

    let fullName = "\(node.name.text)(\(argumentLabelsStr))"

    var funcDecl = ImportedFunc(
      parentName: currentTypeName.map { translator.importedTypes[$0] }??.name,
      identifier: fullName,
      returnType: javaResultType,
      parameters: params
    )
    funcDecl.swiftDeclRaw = "\(node.trimmed)"  // TODO: rethink this, it's useful for comments in Java

    // Retrieve the mangled name, if available.
    if let mangledName = node.mangledNameFromComment {
      funcDecl.swiftMangledName = mangledName
    }

    if let currentTypeName {
      log.info("Record method in \(currentTypeName)")
      translator.importedTypes[currentTypeName]?.methods.append(funcDecl)
    } else {
      translator.importedGlobalFuncs.append(funcDecl)
    }

    return .skipChildren
  }

  override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
    guard let currentTypeName,
            let currentType = translator.importedTypes[currentTypeName] else {
      fatalError("Initializer must be within a current type, was: \(node)")
    }
    guard node.shouldImport(log: log) else {
      return .skipChildren
    }

    self.log.info("Import initializer: \(node.kind) \(currentType.name.javaType.description)")
    let params: [ImportedParam]
    do {
      params = try node.signature.parameterClause.parameters.map { param in
        // TODO: more robust parameter handling
        // TODO: More robust type handling
        return ImportedParam(
          param: param,
          type: try mapTypeToJava(name: param.type)
        )
      }
    } catch {
      self.log.info("Unable to import initializer due to \(error)")
      return .skipChildren
    }

    let initIdentifier =
      "init(\(params.compactMap { $0.effectiveName ?? "_" }.joined(separator: ":")))"

    var funcDecl = ImportedFunc(
      parentName: currentType.name,
      identifier: initIdentifier,
      returnType: currentType.name,
      parameters: params
    )
    funcDecl.isInit = true
    funcDecl.swiftDeclRaw = "\(node.trimmed)"  // TODO: rethink this, it's useful for comments in Java

    // Retrieve the mangled name, if available.
    if let mangledName = node.mangledNameFromComment {
      funcDecl.swiftMangledName = mangledName
    }

    log.info("Record initializer method in \(currentType.name.javaType.description): \(funcDecl.identifier)")
    translator.importedTypes[currentTypeName]!.initializers.append(funcDecl)

    return .skipChildren
  }
}

extension ClassDeclSyntax {
  func shouldImport(log: Logger) -> Bool {
    guard (accessControlModifiers.first { $0.isPublic }) != nil else {
      log.trace("Cannot import \(self.name) because: is not public")
      return false
    }

    return true
  }
}

extension InitializerDeclSyntax {
  func shouldImport(log: Logger) -> Bool {
    let isFailable = self.optionalMark != nil

    if isFailable {
      log.warning("Skip importing failable initializer: \(self)")
      return false
    }

    // Ok, import it
    return true
  }
}

extension FunctionDeclSyntax {
  func shouldImport(log: Logger) -> Bool {
    guard (accessControlModifiers.first { $0.isPublic }) != nil else {
      log.trace("Cannot import \(self.name) because: is not public")
      return false
    }

    return true
  }
}

extension Swift2JavaVisitor {
  // TODO: this is more more complicated, we need to know our package and imports etc
  func mapTypeToJava(name swiftType: TypeSyntax) throws -> ImportedTypeName {
    return try cCompatibleType(for: swiftType).importedTypeName
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
