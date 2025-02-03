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
  var selfParameter: SwiftSelfParameter?
  var parameters: [SwiftParameter]
  var result: SwiftResult
}

/// Describes the "self" parameter of a Swift function signature.
enum SwiftSelfParameter: Equatable {
  /// 'self' is an instance parameter.
  case instance(SwiftParameter)

  /// 'self' is a metatype for a static method. We only need the type to
  /// form the call.
  case staticMethod(SwiftType)

  /// 'self' is the type for a call to an initializer. We only need the type
  /// to form the call.
  case initializer(SwiftType)
}

extension SwiftFunctionSignature {
  /// Create a function declaration with the given name that has this
  /// signature.
  package func createFunctionDecl(_ name: String) -> FunctionDeclSyntax {
    let parametersStr = parameters.map(\.description).joined(separator: ", ")

    let resultWithArrow: String
    if result.type.isVoid {
      resultWithArrow = ""
    } else {
      resultWithArrow = " -> \(result.type.description)"
    }

    let decl: DeclSyntax = """
      func \(raw: name)(\(raw: parametersStr))\(raw: resultWithArrow) {
        // implementation
      }
      """
    return decl.cast(FunctionDeclSyntax.self)
  }
}

extension SwiftFunctionSignature {
  init(
    _ node: InitializerDeclSyntax,
    enclosingType: SwiftType?,
    symbolTable: SwiftSymbolTable
  ) throws {
    guard let enclosingType else {
      throw SwiftFunctionTranslationError.missingEnclosingType(node)
    }

    // We do not yet support failable initializers.
    if node.optionalMark != nil {
      throw SwiftFunctionTranslationError.failableInitializer(node)
    }

    // Prohibit generics for now.
    if let generics = node.genericParameterClause {
      throw SwiftFunctionTranslationError.generic(generics)
    }

    self.selfParameter = .initializer(enclosingType)
    self.result = SwiftResult(convention: .direct, type: enclosingType)
    self.parameters = try Self.translateFunctionSignature(
      node.signature,
      symbolTable: symbolTable
    )
  }

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
      var isStatic = false
      for modifier in node.modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.mutating): isMutating = true
        case .keyword(.static): isStatic = true
        case .keyword(.consuming): isConsuming = true
        case .keyword(.class): throw SwiftFunctionTranslationError.classMethod(modifier.name)
        default: break
        }
      }

      if isStatic {
        self.selfParameter = .staticMethod(enclosingType)
      } else {
        self.selfParameter = .instance(
          SwiftParameter(
            convention: isMutating ? .inout : isConsuming ? .consuming : .byValue,
            type: enclosingType
          )
        )
      }
    } else {
      self.selfParameter = nil
    }

    // Translate the parameters.
    self.parameters = try Self.translateFunctionSignature(
      node.signature,
      symbolTable: symbolTable
    )

    // Translate the result type.
    if let resultType = node.signature.returnClause?.type {
      self.result = try SwiftResult(
        convention: .direct,
        type: SwiftType(resultType, symbolTable: symbolTable)
      )
    } else {
      self.result = SwiftResult(convention: .direct, type: .tuple([]))
    }

    // Prohibit generics for now.
    if let generics = node.genericParameterClause {
      throw SwiftFunctionTranslationError.generic(generics)
    }
  }

  /// Translate the function signature, returning the list of translated
  /// parameters.
  static func translateFunctionSignature(
    _ signature: FunctionSignatureSyntax,
    symbolTable: SwiftSymbolTable
  ) throws -> [SwiftParameter] {
    // FIXME: Prohibit effects for now.
    if let throwsClause = signature.effectSpecifiers?.throwsClause {
      throw SwiftFunctionTranslationError.throws(throwsClause)
    }
    if let asyncSpecifier = signature.effectSpecifiers?.asyncSpecifier {
      throw SwiftFunctionTranslationError.async(asyncSpecifier)
    }

    return try signature.parameterClause.parameters.map { param in
      try SwiftParameter(param, symbolTable: symbolTable)
    }
  }
}

enum SwiftFunctionTranslationError: Error {
  case `throws`(ThrowsClauseSyntax)
  case async(TokenSyntax)
  case generic(GenericParameterClauseSyntax)
  case classMethod(TokenSyntax)
  case missingEnclosingType(InitializerDeclSyntax)
  case failableInitializer(InitializerDeclSyntax)
}
