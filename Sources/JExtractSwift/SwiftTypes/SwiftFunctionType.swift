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

struct SwiftFunctionType: Equatable {
  enum Convention: Equatable {
    case swift
    case c
  }

  var convention: Convention
  var parameters: [SwiftParameter]
  var resultType: SwiftType
}

extension SwiftFunctionType: CustomStringConvertible {
  var description: String {
    return  "(\(parameters.map { $0.descriptionInType } )) -> \(resultType.description)"
  }
}

extension SwiftFunctionType {
  init(
    _ node: FunctionTypeSyntax,
    convention: Convention,
    symbolTable: SwiftSymbolTable
  ) throws {
    self.convention = convention
    self.parameters = try node.parameters.map { param in
      let isInout = param.inoutKeyword != nil
      return SwiftParameter(
        convention: isInout ? .inout : .byValue,
        type: try SwiftType(param.type, symbolTable: symbolTable)
      )
    }

    self.resultType = try SwiftType(node.returnClause.type, symbolTable: symbolTable)

    // check for effect specifiers
    if let throwsClause = node.effectSpecifiers?.throwsClause {
      throw SwiftFunctionTranslationError.throws(throwsClause)
    }
    if let asyncSpecifier = node.effectSpecifiers?.asyncSpecifier {
      throw SwiftFunctionTranslationError.async(asyncSpecifier)
    }
  }
}
