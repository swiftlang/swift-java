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

enum JavaFieldMacro {}

extension JavaFieldMacro: AccessorMacro {
  static func expansion(
    of node: AttributeSyntax,
    providingAccessorsOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [AccessorDeclSyntax] {
    guard let varDecl = declaration.as(VariableDeclSyntax.self),
      let binding = varDecl.bindings.first,
      let fieldNameAsWritten = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.trimmed.text,
      let fieldType = binding.typeAnnotation?.type.trimmed,
      binding.accessorBlock == nil
    else {
      return []
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

    let getter: AccessorDeclSyntax = """
      get { self[javaFieldName: \(literal: fieldName), fieldType: \(fieldType).self] }
      """

    let setter: AccessorDeclSyntax = """
      nonmutating set { self[javaFieldName: \(literal: fieldName), fieldType: \(fieldType).self] = newValue }
      """

    return [getter, setter]
  }
}
