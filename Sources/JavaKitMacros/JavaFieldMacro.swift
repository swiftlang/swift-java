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
import SwiftSyntaxMacros

package enum JavaFieldMacro {}

extension JavaFieldMacro: AccessorMacro {
  package static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard let varDecl = declaration.as(VariableDeclSyntax.self),
      let binding = varDecl.bindings.first,
      let fieldNameAsWritten = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed.text,
      let fieldType = binding.typeAnnotation?.type.typeReference,
      binding.accessorBlock == nil
    else {
      return []
    }

    let isStatic = node.attributeName.trimmedDescription == "JavaStaticField"
    guard !isStatic || isInJavaClassContext(context: context) else {
      throw MacroExpansionErrorMessage("Cannot use @JavaStaticField outside of a JavaClass instance")
    }

    // Dig out the Java field name, if provided. Otherwise, use the name as written.
    let fieldName =
      if case .argumentList(let arguments) = node.arguments,
        let wrapperTypeNameExpr = arguments.first?.expression,
        let stringLiteral = wrapperTypeNameExpr.as(StringLiteralExprSyntax.self),
        stringLiteral.segments.count == 1,
        case let .stringSegment(classNameSegment)? = stringLiteral.segments.first
      {
        classNameSegment.content.text
      } else {
        fieldNameAsWritten
      }

    let createSetter =
    if case .argumentList(let arguments) = node.arguments,
       let wrapperIsBoolean = arguments.first(where: { $0.label?.text == "isFinal" })?.expression,
        let booleanLiteral = wrapperIsBoolean.as(BooleanLiteralExprSyntax.self)
    {
      booleanLiteral.literal.text == "false" // Create the setter if we are not final
    } else {
      true
    }

    let getter: AccessorDeclSyntax = """
      get { self[javaFieldName: \(literal: fieldName), fieldType: \(fieldType).self] }
      """

    var accessors: [AccessorDeclSyntax] = [
      getter
    ]

    let nonmutatingModifier =
      (context.lexicalContext.first?.is(ClassDeclSyntax.self) ?? false ||
       context.lexicalContext.first?.is(ExtensionDeclSyntax.self) ?? false)
        ? ""
        : "nonmutating "

    if createSetter {
      let setter: AccessorDeclSyntax = """
        \(raw: nonmutatingModifier)set { self[javaFieldName: \(literal: fieldName), fieldType: \(fieldType).self] = newValue }
        """
      accessors.append(setter)
    }

    return accessors
  }

  private static func isInJavaClassContext(context: some MacroExpansionContext) -> Bool {
    for lexicalContext in context.lexicalContext {
      if let classSyntax = lexicalContext.as(ExtensionDeclSyntax.self) {
        return classSyntax.extendedType.trimmedDescription.starts(with: "JavaClass")
      }
    }

    return false
  }
}
