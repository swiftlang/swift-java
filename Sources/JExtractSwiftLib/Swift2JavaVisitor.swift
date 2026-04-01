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
import SwiftJavaConfigurationShared
import SwiftParser
import SwiftSyntax

final class Swift2JavaVisitor {
  let translator: Swift2JavaTranslator
  var config: Configuration {
    self.translator.config
  }

  init(translator: Swift2JavaTranslator) {
    self.translator = translator
  }

  var log: Logger { translator.log }

  /// Constrained extensions deferred until specializations are applied
  private var deferredConstrainedExtensions: [(ImportedNominalType, ExtensionDeclSyntax, String)] = []

  func visit(inputFile: SwiftJavaInputFile) {
    let node = inputFile.syntax
    for codeItem in node.statements {
      if let declNode = codeItem.item.as(DeclSyntax.self) {
        self.visit(decl: declNode, in: nil, sourceFilePath: inputFile.path)
      }
    }
  }

  func visit(decl node: DeclSyntax, in parent: ImportedNominalType?, sourceFilePath: String) {
    switch node.as(DeclSyntaxEnum.self) {
    case .actorDecl(let node):
      self.visit(nominalDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .classDecl(let node):
      self.visit(nominalDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .structDecl(let node):
      self.visit(nominalDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .enumDecl(let node):
      self.visit(enumDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .protocolDecl(let node):
      self.visit(nominalDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .extensionDecl(let node):
      self.visit(extensionDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .typeAliasDecl(let node):
      self.visit(typeAliasDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .associatedTypeDecl:
      break // TODO: Implement associated types

    case .initializerDecl(let node):
      self.visit(initializerDecl: node, in: parent)
    case .functionDecl(let node):
      self.visit(functionDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .variableDecl(let node):
      self.visit(variableDecl: node, in: parent, sourceFilePath: sourceFilePath)
    case .subscriptDecl(let node):
      self.visit(subscriptDecl: node, in: parent)
    case .enumCaseDecl(let node):
      self.visit(enumCaseDecl: node, in: parent)

    default:
      break
    }
  }

  func visit(
    nominalDecl node: some DeclSyntaxProtocol & DeclGroupSyntax & NamedDeclSyntax
      & WithAttributesSyntax & WithModifiersSyntax,
    in parent: ImportedNominalType?,
    sourceFilePath: String,
  ) {
    guard let importedNominalType = translator.importedNominalType(node, parent: parent) else {
      return
    }

    // Check if there's a specialization entry for this type
    applySpecialization(to: importedNominalType)

    for memberItem in node.memberBlock.members {
      self.visit(decl: memberItem.decl, in: importedNominalType, sourceFilePath: sourceFilePath)
    }
  }

  func visit(
    enumDecl node: EnumDeclSyntax,
    in parent: ImportedNominalType?,
    sourceFilePath: String,
  ) {
    self.visit(nominalDecl: node, in: parent, sourceFilePath: sourceFilePath)

    self.synthesizeRawRepresentableConformance(enumDecl: node, in: parent)
  }

  func visit(
    extensionDecl node: ExtensionDeclSyntax,
    in parent: ImportedNominalType?,
    sourceFilePath: String,
  ) {
    guard parent == nil else {
      // 'extension' in a nominal type is invalid. Ignore
      return
    }
    guard let importedNominalType = translator.importedNominalType(node.extendedType) else {
      return
    }

    // If the extension has where-clause constraints, defer it until specializations are applied
    let whereConstraints = parseWhereConstraints(node.genericWhereClause)
    if !whereConstraints.isEmpty {
      let matchingSpecializations = findMatchingSpecializations(
        extendedType: importedNominalType,
        whereConstraints: whereConstraints,
      )
      if matchingSpecializations.isEmpty {
        // Specializations may not exist yet — defer for later
        deferredConstrainedExtensions.append((importedNominalType, node, sourceFilePath))
        return
      }

      // Visit members in each matching specialization, not the base type
      for specialized in matchingSpecializations {
        for memberItem in node.memberBlock.members {
          self.visit(decl: memberItem.decl, in: specialized, sourceFilePath: sourceFilePath)
        }
      }
      return
    }

    // Unconstrained extension — add to the base type (visible through all specializations)
    importedNominalType.inheritedTypes +=
      node.inheritanceClause?.inheritedTypes.compactMap {
        try? SwiftType($0.type, lookupContext: translator.lookupContext)
      } ?? []

    for memberItem in node.memberBlock.members {
      self.visit(decl: memberItem.decl, in: importedNominalType, sourceFilePath: sourceFilePath)
    }
  }

  func visit(
    functionDecl node: FunctionDeclSyntax,
    in typeContext: ImportedNominalType?,
    sourceFilePath: String,
  ) {
    guard node.shouldExtract(config: config, log: log, in: typeContext) else {
      return
    }

    switch node.name.tokenKind {
    case .binaryOperator, .prefixOperator, .postfixOperator:
      self.log.debug("Skip importing: '\(node.qualifiedNameForDebug)'; Operators are not supported.")
      return
    default:
      break
    }

    self.log.debug("Import function: '\(node.qualifiedNameForDebug)'")

    let signature: SwiftFunctionSignature
    do {
      signature = try SwiftFunctionSignature(
        node,
        enclosingType: typeContext?.swiftType,
        lookupContext: translator.lookupContext,
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
      functionSignature: signature,
    )

    if typeContext?.swiftNominal.isGeneric == true && typeContext?.isSpecialization != true && imported.isStatic {
      log.debug("Skip importing static function in generic type: '\(node.qualifiedNameForDebug)'")
      return
    }

    log.debug("Record imported method \(node.qualifiedNameForDebug)")
    if let typeContext {
      typeContext.methods.append(imported)
    } else {
      translator.importedGlobalFuncs.append(imported)
    }
  }

  func visit(
    enumCaseDecl node: EnumCaseDeclSyntax,
    in typeContext: ImportedNominalType?,
  ) {
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
          lookupContext: translator.lookupContext,
        )

        let caseFunction = ImportedFunc(
          module: translator.swiftModuleName,
          swiftDecl: node,
          name: caseElement.name.text,
          apiKind: .enumCase,
          functionSignature: signature,
        )

        let importedCase = ImportedEnumCase(
          name: caseElement.name.text,
          parameters: parameters ?? [],
          swiftDecl: node,
          enumType: SwiftNominalType(nominalTypeDecl: typeContext.swiftNominal),
          caseFunction: caseFunction,
        )

        typeContext.cases.append(importedCase)
      }
    } catch {
      self.log.debug("Failed to import: \(node.qualifiedNameForDebug); \(error)")
    }
  }

  func visit(
    variableDecl node: VariableDeclSyntax,
    in typeContext: ImportedNominalType?,
    sourceFilePath: String,
  ) {
    guard node.shouldExtract(config: config, log: log, in: typeContext) else {
      return
    }

    guard let binding = node.bindings.first else {
      return
    }

    let varName = "\(binding.pattern.trimmed)"

    self.log.debug("Import variable: \(node.kind) '\(node.qualifiedNameForDebug)'")

    do {
      let supportedAccessors = node.supportedAccessorKinds(binding: binding)
      if supportedAccessors.contains(.get) {
        try importAccessor(
          from: DeclSyntax(node),
          in: typeContext,
          kind: .getter,
          name: varName,
        )
      }
      if supportedAccessors.contains(.set) {
        try importAccessor(
          from: DeclSyntax(node),
          in: typeContext,
          kind: .setter,
          name: varName,
        )
      }
    } catch {
      self.log.debug("Failed to import: \(node.qualifiedNameForDebug); \(error)")
    }
  }

  func visit(
    initializerDecl node: InitializerDeclSyntax,
    in typeContext: ImportedNominalType?,
  ) {
    guard let typeContext else {
      self.log.info("Initializer must be within a current type; \(node)")
      return
    }
    guard node.shouldExtract(config: config, log: log, in: typeContext) else {
      return
    }

    if typeContext.swiftNominal.isGeneric && !typeContext.isSpecialization {
      log.debug("Skip Importing generic type initializer \(node.kind) '\(node.qualifiedNameForDebug)'")
      return
    }

    self.log.debug("Import initializer: \(node.kind) '\(node.qualifiedNameForDebug)'")

    let signature: SwiftFunctionSignature
    do {
      signature = try SwiftFunctionSignature(
        node,
        enclosingType: typeContext.swiftType,
        lookupContext: translator.lookupContext,
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
      functionSignature: signature,
    )

    typeContext.initializers.append(imported)
  }

  private func visit(
    subscriptDecl node: SubscriptDeclSyntax,
    in typeContext: ImportedNominalType?,
  ) {
    guard node.shouldExtract(config: config, log: log, in: typeContext) else {
      return
    }

    guard let accessorBlock = node.accessorBlock else {
      return
    }

    let name = "subscript"
    let accessors = accessorBlock.supportedAccessorKinds()

    do {
      if accessors.contains(.get) {
        try importAccessor(
          from: DeclSyntax(node),
          in: typeContext,
          kind: .subscriptGetter,
          name: name,
        )
      }
      if accessors.contains(.set) {
        try importAccessor(
          from: DeclSyntax(node),
          in: typeContext,
          kind: .subscriptSetter,
          name: name,
        )
      }
    } catch {
      self.log.debug("Failed to import: \(node.qualifiedNameForDebug); \(error)")
    }
  }

  private func importAccessor(
    from node: DeclSyntax,
    in typeContext: ImportedNominalType?,
    kind: SwiftAPIKind,
    name: String,
  ) throws {
    let signature: SwiftFunctionSignature

    switch node.as(DeclSyntaxEnum.self) {
    case .variableDecl(let varNode):
      signature = try SwiftFunctionSignature(
        varNode,
        isSet: kind == .setter,
        enclosingType: typeContext?.swiftType,
        lookupContext: translator.lookupContext,
      )
    case .subscriptDecl(let subscriptNode):
      signature = try SwiftFunctionSignature(
        subscriptNode,
        isSet: kind == .subscriptSetter,
        enclosingType: typeContext?.swiftType,
        lookupContext: translator.lookupContext,
      )
    default:
      log.warning("Not supported declaration type \(node.kind) while calling importAccessor!")
      return
    }

    let imported = ImportedFunc(
      module: translator.swiftModuleName,
      swiftDecl: node,
      name: name,
      apiKind: kind,
      functionSignature: signature,
    )

    if typeContext?.swiftNominal.isGeneric == true && typeContext?.isSpecialization != true && imported.isStatic {
      log.debug("Skip importing static accessor in generic type: '\(node.qualifiedNameForDebug)'")
      return
    }

    log.debug(
      "Record imported variable accessor \(kind == .getter || kind == .subscriptGetter ? "getter" : "setter"):\(node.qualifiedNameForDebug)"
    )
    if let typeContext {
      typeContext.variables.append(imported)
    } else {
      translator.importedGlobalVariables.append(imported)
    }
  }

  private func synthesizeRawRepresentableConformance(
    enumDecl node: EnumDeclSyntax,
    in parent: ImportedNominalType?,
  ) {
    guard let imported = translator.importedNominalType(node, parent: parent) else {
      return
    }

    if let firstInheritanceType = imported.swiftNominal.firstInheritanceType,
      let inheritanceType = try? SwiftType(
        firstInheritanceType,
        lookupContext: translator.lookupContext,
      ),
      inheritanceType.isRawTypeCompatible
    {
      if !imported.variables.contains(where: {
        $0.name == "rawValue" && $0.functionSignature.result.type != inheritanceType
      }) {
        let decl: DeclSyntax = "public var rawValue: \(raw: inheritanceType.description) { get }"
        self.visit(decl: decl, in: imported, sourceFilePath: imported.sourceFilePath)
      }

      if !imported.initializers.contains(where: {
        $0.functionSignature.parameters.count == 1
          && $0.functionSignature.parameters.first?.parameterName == "rawValue"
          && $0.functionSignature.parameters.first?.type == inheritanceType
      }) {
        let decl: DeclSyntax = "public init?(rawValue: \(raw: inheritanceType))"
        self.visit(decl: decl, in: imported, sourceFilePath: imported.sourceFilePath)
      }
    }
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Typealias declarations

  func visit(
    typeAliasDecl node: TypeAliasDeclSyntax,
    in typeContext: ImportedNominalType?,
    sourceFilePath: String,
  ) {
    let javaName = node.name.text
    let rhsType = node.initializer.value

    let genericArgs: [String]
    if let identType = rhsType.as(IdentifierTypeSyntax.self) {
      genericArgs = identType.genericArgumentClause?.arguments.compactMap { $0.argument.trimmedDescription } ?? []
    } else if let memberType = rhsType.as(MemberTypeSyntax.self) {
      genericArgs = memberType.genericArgumentClause?.arguments.compactMap { $0.argument.trimmedDescription } ?? []
    } else {
      return
    }

    // Only register as specialization if the RHS has generic arguments
    guard !genericArgs.isEmpty else { return }

    // Resolve the base type through the symbol table
    guard let baseType = translator.importedNominalType(rhsType) else {
      log.debug("Could not resolve base type for specialization: \(rhsType.trimmedDescription)")
      return
    }

    registerSpecialization(
      javaName: javaName,
      baseType: baseType,
      genericArgs: genericArgs,
      rhsDescription: rhsType.trimmedDescription,
    )
  }

  /// Register a specialization from a typealias that specializes a generic type
  private func registerSpecialization(
    javaName: String,
    baseType: ImportedNominalType,
    genericArgs: [String],
    rhsDescription: String,
  ) {
    // Build substitutions dict from the generic parameters
    var substitutions: [String: String] = [:]
    if baseType.swiftNominal.isGeneric {
      let genericParams = baseType.swiftNominal.genericParameters.map { $0.name }
      for (i, param) in genericParams.enumerated() {
        if i < genericArgs.count {
          substitutions[param] = genericArgs[i]
        }
      }
    }

    let specialized: ImportedNominalType
    do {
      specialized = try baseType.specialize(as: javaName, with: substitutions)
    } catch {
      log.warning("Failed to specialize \(baseType.baseTypeName) as \(javaName): \(error)")
      return
    }
    translator.specializations[baseType, default: []].insert(specialized)
    log.info("Registered specialization: \(javaName) = \(rhsDescription)")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Specialization support

  /// Apply specializations to a type if matching entries exist
  func applySpecialization(to importedType: ImportedNominalType) {
    guard let specializations = translator.specializations[importedType] else {
      return
    }

    for specialized in specializations {
      translator.importedTypes[specialized.effectiveJavaName] = specialized
      log.info("Applied specialization: \(specialized.effectiveJavaName) -> \(specialized.effectiveSwiftTypeName)")
    }
  }

  /// Apply specializations that were registered after their target types were visited,
  /// then process any deferred constrained extensions
  func applyPendingSpecializations() {
    for (_, specializations) in translator.specializations {
      for specialized in specializations {
        if translator.importedTypes[specialized.effectiveJavaName] != nil {
          continue
        }
        translator.importedTypes[specialized.effectiveJavaName] = specialized
        log.info("Applied pending specialization: \(specialized.effectiveJavaName) -> \(specialized.effectiveSwiftTypeName)")
      }
    }

    // Process constrained extensions that were deferred
    for (baseType, node, sourceFilePath) in deferredConstrainedExtensions {
      let whereConstraints = parseWhereConstraints(node.genericWhereClause)
      let matchingSpecializations = findMatchingSpecializations(
        extendedType: baseType,
        whereConstraints: whereConstraints,
      )
      guard !matchingSpecializations.isEmpty else {
        log.debug("Skipping deferred constrained extension of \(node.extendedType.trimmedDescription) — no matching specialization")
        continue
      }
      for specialized in matchingSpecializations {
        for memberItem in node.memberBlock.members {
          self.visit(decl: memberItem.decl, in: specialized, sourceFilePath: sourceFilePath)
        }
      }
    }
    deferredConstrainedExtensions.removeAll()
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Constrained extension merging

  /// Parse where clause constraints into a dictionary mapping param names to concrete types
  private func parseWhereConstraints(_ whereClause: GenericWhereClauseSyntax?) -> [String: String] {
    guard let whereClause else { return [:] }
    var constraints: [String: String] = [:]
    for requirement in whereClause.requirements {
      if case .sameTypeRequirement(let sameType) = requirement.requirement {
        let lhs = sameType.leftType.trimmedDescription
        let rhs = sameType.rightType.trimmedDescription
        constraints[lhs] = rhs
      }
    }
    return constraints
  }

  /// Find specializations whose type args match the given where-clause constraints
  private func findMatchingSpecializations(
    extendedType: ImportedNominalType,
    whereConstraints: [String: String],
  ) -> [ImportedNominalType] {
    guard let specializations = translator.specializations[extendedType] else {
      return []
    }
    return specializations.filter { specialized in
      constraintsMatchSpecialization(whereConstraints, specialized: specialized)
    }
  }

  /// Check if where clause constraints match a specialization's generic arguments
  private func constraintsMatchSpecialization(
    _ constraints: [String: String],
    specialized: ImportedNominalType,
  ) -> Bool {
    for (paramName, concreteType) in constraints {
      if let expectedType = specialized.genericArguments[paramName] {
        if expectedType != concreteType {
          return false
        }
      }
      // If the param isn't in the mapping, we allow it (might be a secondary constraint)
    }
    return true
  }
}

extension DeclSyntaxProtocol where Self: WithModifiersSyntax & WithAttributesSyntax {
  func shouldExtract(config: Configuration, log: Logger, in parent: ImportedNominalType?) -> Bool {
    // @JavaExport overrides all filters — always extract
    if attributes.contains(where: { $0.isJavaExport }) {
      return true
    }

    let meetsRequiredAccessLevel: Bool =
      switch config.effectiveMinimumInputAccessLevelMode {
      case .public: self.isPublic(in: parent?.swiftNominal.syntax)
      case .package: self.isAtLeastPackage
      case .internal: self.isAtLeastInternal
      }

    guard meetsRequiredAccessLevel else {
      log.debug(
        "Skip import '\(self.qualifiedNameForDebug)': not at least \(config.effectiveMinimumInputAccessLevelMode)"
      )
      return false
    }
    guard !attributes.contains(where: { $0.isSwiftJavaMacro }) else {
      log.debug("Skip import '\(self.qualifiedNameForDebug)': is Java")
      return false
    }

    return true
  }
}
