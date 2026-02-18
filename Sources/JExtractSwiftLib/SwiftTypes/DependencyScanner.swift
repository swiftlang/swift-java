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

/// Scan importing modules.
func importingModules(sourceFile: SourceFileSyntax) -> [ImportedSwiftModule] {
  var importingModuleNames: [ImportedSwiftModule] = []
  for item in sourceFile.statements {
    if let importDecl = item.item.as(ImportDeclSyntax.self) {
      guard let moduleName = importDecl.path.first?.name.text else {
        continue
      }
      importingModuleNames.append(
        ImportedSwiftModule(name: moduleName, availableWithModuleName: nil, alternativeModuleNames: [])
      )
    } else if let ifConfigDecl = item.item.as(IfConfigDeclSyntax.self) {
      importingModuleNames.append(contentsOf: modules(from: ifConfigDecl))
    }
  }
  return importingModuleNames
}

private func modules(from ifConfigDecl: IfConfigDeclSyntax) -> [ImportedSwiftModule] {
  guard
    let firstClause = ifConfigDecl.clauses.first,
    let calledExpression = firstClause.condition?.as(FunctionCallExprSyntax.self)?.calledExpression.as(
      DeclReferenceExprSyntax.self
    ),
    calledExpression.baseName.text == "canImport"
  else {
    return []
  }

  var modules: [ImportedSwiftModule] = []
  modules.reserveCapacity(ifConfigDecl.clauses.count)

  for (index, clause) in ifConfigDecl.clauses.enumerated() {
    let importedModuleNames =
      clause.elements?.as(CodeBlockItemListSyntax.self)?
      .compactMap { CodeBlockItemSyntax($0) }
      .compactMap { $0.item.as(ImportDeclSyntax.self) }
      .compactMap { $0.path.first?.name.text } ?? []

    let importModuleName: String? =
      if let funcCallExpr = clause.condition?.as(FunctionCallExprSyntax.self),
        let calledDeclReference = funcCallExpr.calledExpression.as(DeclReferenceExprSyntax.self),
        calledDeclReference.baseName.text == "canImport",
        let moduleNameSyntax = funcCallExpr.arguments.first?.expression.as(DeclReferenceExprSyntax.self)
      {
        moduleNameSyntax.baseName.text
      } else {
        nil
      }

    let clauseModules = importedModuleNames.map {
      ImportedSwiftModule(
        name: $0,
        availableWithModuleName: importModuleName,
        alternativeModuleNames: []
      )
    }

    // Assume single import from #else statement is fallback and use it as main source of symbols
    if clauseModules.count == 1 && index == (ifConfigDecl.clauses.count - 1)
      && clause.poundKeyword.tokenKind == .poundElse
    {
      var fallbackModule: ImportedSwiftModule = clauseModules[0]
      var moduleNames: [String] = []
      moduleNames.reserveCapacity(modules.count)

      for i in 0..<modules.count {
        modules[i].alternativeModuleNames.insert(fallbackModule.name)
        moduleNames.append(modules[i].name)
      }

      fallbackModule.alternativeModuleNames = Set(modules.map(\.name))
      fallbackModule.isMainSourceOfSymbols = true
    }

    modules.append(contentsOf: clauseModules)
  }

  return modules
}
