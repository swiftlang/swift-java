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
import SwiftSyntaxBuilder

/// Provides a complete signature for a Swift function, which includes its
/// parameters and return type.
@_spi(Testing)
public struct SwiftFunctionSignature: Equatable {
  var isStaticOrClass: Bool
  var selfParameter: SwiftParameter?
  var parameters: [SwiftParameter]
  var result: SwiftResult
}

extension SwiftFunctionSignature {
  /// Create a function declaration with the given name that has this
  /// signature.
  package func createFunctionDecl(_ name: String) -> FunctionDeclSyntax {
    let parametersStr = parameters.map(\.description).joined(separator: ", ")
    let resultStr = result.type.description
    let decl: DeclSyntax = """
      func \(raw: name)(\(raw: parametersStr)) -> \(raw: resultStr) {
        // implementation
      }
      """
    return decl.cast(FunctionDeclSyntax.self)
  }
}

extension SwiftFunctionSignature {
  init(
    _ node: FunctionDeclSyntax,
    enclosingType: SwiftType?,
    symbolTable: SwiftSymbolTable
  ) throws {
    // If this is a member of a type, so we will have a self parameter. Figure out the
    // type and convention for the self parameter.
    if let enclosingType {
      var isMutating = false
      var isConsuming = false
      var isStaticOrClass = false
      for modifier in node.modifiers {
        switch modifier.name {
        case .keyword(.mutating): isMutating = true
        case .keyword(.static), .keyword(.class): isStaticOrClass = true
        case .keyword(.consuming): isConsuming = true
        default: break
        }
      }

      if isStaticOrClass {
        self.selfParameter = SwiftParameter(
          convention: .byValue,
          type: .metatype(
            enclosingType
          )
        )
      } else {
        self.selfParameter = SwiftParameter(
          convention: isMutating ? .inout : isConsuming ? .consuming : .byValue,
          type: enclosingType
        )
      }

      self.isStaticOrClass = isStaticOrClass
    } else {
      self.selfParameter = nil
      self.isStaticOrClass = false
    }

    // Translate the parameters.
    self.parameters = try node.signature.parameterClause.parameters.map { param in
      try SwiftParameter(param, symbolTable: symbolTable)
    }

    // Translate the result type.
    if let resultType = node.signature.returnClause?.type {
      self.result = try SwiftResult(
        convention: .direct,
        type: SwiftType(resultType, symbolTable: symbolTable)
      )
    } else {
      self.result = SwiftResult(convention: .direct, type: .tuple([]))
    }

    // FIXME: Prohibit effects for now.
    if let throwsClause = node.signature.effectSpecifiers?.throwsClause {
      throw SwiftFunctionTranslationError.throws(throwsClause)
    }
    if let asyncSpecifier = node.signature.effectSpecifiers?.asyncSpecifier {
      throw SwiftFunctionTranslationError.async(asyncSpecifier)
    }

    // Prohibit generics for now.
    if let generics = node.genericParameterClause {
      throw SwiftFunctionTranslationError.generic(generics)
    }
  }
}

enum SwiftFunctionTranslationError: Error {
  case `throws`(ThrowsClauseSyntax)
  case async(TokenSyntax)
  case generic(GenericParameterClauseSyntax)
}
