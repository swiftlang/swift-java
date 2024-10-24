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

import SwiftSyntax
import SwiftSyntaxBuilder
@_spi(Testing) import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

package enum JavaMethodMacro {}

extension JavaMethodMacro: BodyMacro {
  package static func expansion(
    of node: AttributeSyntax,
    providingBodyFor declaration: some DeclSyntaxProtocol & WithOptionalCodeBlockSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    // @JavaMethod only provides an implementation when the method was
    // imported from Java.
    let mode = GenerationMode(expansionContext: context)

    // FIXME: nil is a workaround for the fact that extension JavaClass doesn't
    // currently have the annotations we need. We should throw
    // MacroErrors.macroOutOfContext(node.attributeName.trimmedDescription)

    switch mode {
    case .javaImplementation, .exportToJava:
      return declaration.body.map { Array($0.statements) } ?? []

    case .importFromJava, nil:
      break
    }

    // Handle initializers separately.
    if let initDecl = declaration.as(InitializerDeclSyntax.self) {
      return try bridgeInitializer(initDecl, in: context)
    }

    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      fatalError("not a function")
    }

    let isStatic = node.attributeName.trimmedDescription == "JavaStaticMethod"
    let funcName = funcDecl.name.text
    let params = funcDecl.signature.parameterClause.parameters
    let resultType: String =
      funcDecl.signature.returnClause.map { result in
        ", resultType: \(result.type.trimmedDescription).self"
      } ?? ""
    let paramNames = params.map { param in param.parameterName?.text ?? "" }.joined(separator: ", ")

    let parametersAsArgs: String
    if paramNames.isEmpty {
      parametersAsArgs = ""
    } else {
      parametersAsArgs = ", arguments: \(paramNames)"
    }

    let tryKeyword =
      funcDecl.signature.effectSpecifiers?.throwsClause != nil
      ? "try" : "try!"

    return [
      "return \(raw: tryKeyword) dynamicJava\(raw: isStatic ? "Static" : "")MethodCall(methodName: \(literal: funcName)\(raw: parametersAsArgs)\(raw: resultType))"
    ]
  }

  /// Bridge an initializer into a call to Java.
  private static func bridgeInitializer(
    _ initDecl: InitializerDeclSyntax,
    in context: some MacroExpansionContext
  ) throws -> [CodeBlockItemSyntax] {
    // Extract the "environment" parameter.
    guard let environmentIndex = initDecl.signature.parameterClause.parameters.indexOfParameter(named: "environment")
    else {
      throw MacroErrors.missingEnvironment
    }

    // Collect the arguments that need to be passed through to the
    // Java constructor.
    let parameters = initDecl.signature.parameterClause.parameters
    var arguments: String = ""
    for paramIndex in parameters.indices {
      // Don't include the "environment" parameter.
      if paramIndex == environmentIndex {
        continue
      }

      let param = parameters[paramIndex]
      arguments += "\(param.parameterName!).self, "
    }

    if !arguments.isEmpty {
      arguments = ", arguments: \(arguments.dropLast(2))"
    }

    let tryKeyword =
      initDecl.signature.effectSpecifiers?.throwsClause != nil
      ? "try" : "try!"

    return [
      """
      let _environment = if let environment {
          environment
      } else {
          \(raw: tryKeyword) JavaVirtualMachine.shared().environment()
      }
      self = \(raw: tryKeyword) Self.dynamicJavaNewObject(in: _environment\(raw: arguments))
      """
    ]
  }
}

extension FunctionParameterListSyntax {
  func indexOfParameter(named name: String) -> Index? {
    return firstIndex { $0.parameterName?.text == name }
  }
}
