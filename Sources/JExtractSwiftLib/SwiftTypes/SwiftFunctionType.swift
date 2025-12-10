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
  var isEscaping: Bool = false
}

extension SwiftFunctionType: CustomStringConvertible {
  var description: String {
    let parameterString = parameters.map { $0.descriptionInType }.joined(separator: ", ")
    let conventionPrefix = switch convention {
    case .c: "@convention(c) "
    case .swift: ""
    }
    let escapingPrefix = isEscaping ? "@escaping " : ""
    return  "\(escapingPrefix)\(conventionPrefix)(\(parameterString)) -> \(resultType.description)"
  }
}

extension SwiftFunctionType {
  init(
    _ node: FunctionTypeSyntax,
    convention: Convention,
    isEscaping: Bool = false,
    lookupContext: SwiftTypeLookupContext
  ) throws {
    self.convention = convention
    self.isEscaping = isEscaping
    self.parameters = try node.parameters.map { param in
      let isInout = param.inoutKeyword != nil
      return SwiftParameter(
        convention: isInout ? .inout : .byValue,
        type: try SwiftType(param.type, lookupContext: lookupContext)
      )
    }

    self.resultType = try SwiftType(node.returnClause.type, lookupContext: lookupContext)

    // check for effect specifiers
    if let throwsClause = node.effectSpecifiers?.throwsClause {
      throw SwiftFunctionTranslationError.throws(throwsClause)
    }
    if let asyncSpecifier = node.effectSpecifiers?.asyncSpecifier {
      throw SwiftFunctionTranslationError.async(asyncSpecifier)
    }
  }
}
