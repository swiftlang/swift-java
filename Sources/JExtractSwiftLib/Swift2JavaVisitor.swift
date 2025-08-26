//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
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
import SwiftJavaConfigurationShared

final class Swift2JavaVisitor {
  let translator: Swift2JavaTranslator
  var config: Configuration {
    self.translator.config
  }

  init(translator: Swift2JavaTranslator) {
    self.translator = translator
  }

  var log: Logger { translator.log }

  func visit(sourceFile node: SourceFileSyntax) {
    for codeItem in node.statements {
      if let declNode = codeItem.item.as(DeclSyntax.self) {
        self.visit(decl: declNode, in: nil)
      }
    }
  }

  func visit(decl node: DeclSyntax, in parent: ImportedNominalType?) {
    switch node.as(DeclSyntaxEnum.self) {
    case .actorDecl(let node):
      self.visit(nominalDecl: node, in: parent)
    case .classDecl(let node):
      self.visit(nominalDecl: node, in: parent)
    case .structDecl(let node):
      self.visit(nominalDecl: node, in: parent)
    case .enumDecl(let node):
      self.visit(enumDecl: node, in: parent)
    case .protocolDecl(let node):
      self.visit(nominalDecl: node, in: parent)
    case .extensionDecl(let node):
      self.visit(extensionDecl: node, in: parent)
    case .typeAliasDecl:
      break // TODO: Implement; https://github.com/swiftlang/swift-java/issues/338
    case .associatedTypeDecl:
      break // TODO: Implement

    case .initializerDecl(let node):
      self.visit(initializerDecl: node, in: parent)
    case .functionDecl(let node):
      self.visit(functionDecl: node, in: parent)
    case .variableDecl(let node):
      self.visit(variableDecl: node, in: parent)
    case .subscriptDecl:
      // TODO: Implement
      break
    case .enumCaseDecl(let node):
      self.visit(enumCaseDecl: node, in: parent)

    default:
      break
    }
  }

  func visit(
    nominalDecl node: some DeclSyntaxProtocol & DeclGroupSyntax & NamedDeclSyntax & WithAttributesSyntax & WithModifiersSyntax,
    in parent: ImportedNominalType?
  ) {
    guard let importedNominalType = translator.importedNominalType(node, parent: parent) else {
      return
    }
    for memberItem in node.memberBlock.members {
      self.visit(decl: memberItem.decl, in: importedNominalType)
    }
  }

  func visit(enumDecl node: EnumDeclSyntax, in parent: ImportedNominalType?) {
    self.visit(nominalDecl: node, in: parent)

    self.synthesizeRawRepresentableConformance(enumDecl: node, in: parent)
  }

  func visit(extensionDecl node: ExtensionDeclSyntax, in parent: ImportedNominalType?) {
    guard parent == nil else {
      // 'extension' in a nominal type is invalid. Ignore
      return
    }
    guard let importedNominalType = translator.importedNominalType(node.extendedType) else {
      return
    }
    for memberItem in node.memberBlock.members {
      self.visit(decl: memberItem.decl, in: importedNominalType)
    }
  }

  func visit(functionDecl node: FunctionDeclSyntax, in typeContext: ImportedNominalType?) {
    guard node.shouldExtract(config: config, log: log) else {
      return
    }

    self.log.debug("Import function: '\(node.qualifiedNameForDebug)'")

    let signature: SwiftFunctionSignature
    do {
      signature = try SwiftFunctionSignature(
        node,
        enclosingType: typeContext?.swiftType,
        lookupContext: translator.lookupContext
      )
    } catch {
      self.log.debug("Failed to import: '\(node.qualifiedNameForDebug)'; \(error)")
      return
    }

    let imported = ImportedFunc(
      module: translator.swiftModuleName,
      swiftDecl: node,
      name: node.name.text,
      apiKind: .function,
      functionSignature: signature
    )

    log.debug("Record imported method \(node.qualifiedNameForDebug)")
    if let typeContext {
      typeContext.methods.append(imported)
    } else {
      translator.importedGlobalFuncs.append(imported)
    }
  }

  func visit(enumCaseDecl node: EnumCaseDeclSyntax, in typeContext: ImportedNominalType?) {
    guard let typeContext else {
      self.log.info("Enum case must be within a current type; \(node)")
      return
    }

    do {
      for caseElement in node.elements {
        self.log.debug("Import case \(caseElement.name) of enum \(node.qualifiedNameForDebug)")

        let parameters = try caseElement.parameterClause?.parameters.map {
          try SwiftEnumCaseParameter($0, lookupContext: translator.lookupContext)
        }

        let signature = try SwiftFunctionSignature(
          caseElement,
          enclosingType: typeContext.swiftType,
          lookupContext: translator.lookupContext
        )

        let caseFunction = ImportedFunc(
          module: translator.swiftModuleName,
          swiftDecl: node,
          name: caseElement.name.text,
          apiKind: .enumCase,
          functionSignature: signature
        )

        let importedCase = ImportedEnumCase(
          name: caseElement.name.text,
          parameters: parameters ?? [],
          swiftDecl: node,
          enumType: SwiftNominalType(nominalTypeDecl: typeContext.swiftNominal),
          caseFunction: caseFunction
        )

        typeContext.cases.append(importedCase)
      }
    } catch {
      self.log.debug("Failed to import: \(node.qualifiedNameForDebug); \(error)")
    }
  }

  func visit(variableDecl node: VariableDeclSyntax, in typeContext: ImportedNominalType?) {
    guard node.shouldExtract(config: config, log: log) else {
      return
    }

    guard let binding = node.bindings.first else {
      return
    }

    let varName = "\(binding.pattern.trimmed)"

    self.log.debug("Import variable: \(node.kind) '\(node.qualifiedNameForDebug)'")

    func importAccessor(kind: SwiftAPIKind) throws {
      let signature = try SwiftFunctionSignature(
        node,
        isSet: kind == .setter,
        enclosingType: typeContext?.swiftType,
        lookupContext: translator.lookupContext
      )

      let imported = ImportedFunc(
        module: translator.swiftModuleName,
        swiftDecl: node,
        name: varName,
        apiKind: kind,
        functionSignature: signature
      )

      log.debug("Record imported variable accessor \(kind == .getter ? "getter" : "setter"):\(node.qualifiedNameForDebug)")
      if let typeContext {
        typeContext.variables.append(imported)
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
    }
  }

  func visit(initializerDecl node: InitializerDeclSyntax, in typeContext: ImportedNominalType?) {
    guard let typeContext else {
      self.log.info("Initializer must be within a current type; \(node)")
      return
    }
    guard node.shouldExtract(config: config, log: log) else {
      return
    }

    self.log.debug("Import initializer: \(node.kind) '\(node.qualifiedNameForDebug)'")

    let signature: SwiftFunctionSignature
    do {
      signature = try SwiftFunctionSignature(
        node,
        enclosingType: typeContext.swiftType,
        lookupContext: translator.lookupContext
      )
    } catch {
      self.log.debug("Failed to import: \(node.qualifiedNameForDebug); \(error)")
      return
    }
    let imported = ImportedFunc(
      module: translator.swiftModuleName,
      swiftDecl: node,
      name: "init",
      apiKind: .initializer,
      functionSignature: signature
    )

    typeContext.initializers.append(imported)
  }

  private func synthesizeRawRepresentableConformance(enumDecl node: EnumDeclSyntax, in parent: ImportedNominalType?) {
    guard let imported = translator.importedNominalType(node, parent: parent) else {
      return
    }

    if let firstInheritanceType = imported.swiftNominal.firstInheritanceType,
      let inheritanceType = try? SwiftType(
        firstInheritanceType,
        lookupContext: translator.lookupContext
      ),
      inheritanceType.isRawTypeCompatible
    {
      if !imported.variables.contains(where: { $0.name == "rawValue" && $0.functionSignature.result.type != inheritanceType }) {
        let decl: DeclSyntax = "public var rawValue: \(raw: inheritanceType.description) { get }"
        self.visit(decl: decl, in: imported)
      }

      imported.variables.first?.signatureString

      if !imported.initializers.contains(where: { $0.functionSignature.parameters.count == 1 && $0.functionSignature.parameters.first?.parameterName == "rawValue" && $0.functionSignature.parameters.first?.type == inheritanceType }) {
        let decl: DeclSyntax = "public init?(rawValue: \(raw: inheritanceType))"
        self.visit(decl: decl, in: imported)
      }
    }
  }
}

extension DeclSyntaxProtocol where Self: WithModifiersSyntax & WithAttributesSyntax {
  func shouldExtract(config: Configuration, log: Logger) -> Bool {
    let meetsRequiredAccessLevel: Bool =
      switch config.effectiveMinimumInputAccessLevelMode {
      case .public: self.isPublic
      case .package: self.isAtLeastPackage
      case .internal: self.isAtLeastInternal
      }

    guard meetsRequiredAccessLevel else {
      log.debug("Skip import '\(self.qualifiedNameForDebug)': not at least \(config.effectiveMinimumInputAccessLevelMode)")
      return false
    }
    guard !attributes.contains(where: { $0.isJava }) else {
      log.debug("Skip import '\(self.qualifiedNameForDebug)': is Java")
      return false
    }

    return true
  }
}
