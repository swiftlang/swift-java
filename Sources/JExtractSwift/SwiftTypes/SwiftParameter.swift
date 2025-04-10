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

struct SwiftParameter: Equatable {
  var convention: SwiftParameterConvention
  var argumentLabel: String?
  var parameterName: String?
  var type: SwiftType
  var canBeDirectReturn = false
}

extension SwiftParameter: CustomStringConvertible {
  var description: String {
    let argumentLabel = self.argumentLabel ?? "_"
    let parameterName = self.parameterName ?? "_"

    return "\(argumentLabel) \(parameterName): \(descriptionInType)"
  }

  var descriptionInType: String {
    let conventionString: String
    switch convention {
    case .byValue:
      conventionString = ""

    case .consuming:
      conventionString = "consuming "

    case .inout:
      conventionString = "inout "
    }

    return conventionString + type.description
  }
}

/// Describes how a parameter is passed.
enum SwiftParameterConvention: Equatable {
  /// The parameter is passed by-value or borrowed.
  case byValue
  /// The parameter is passed by-value but consumed.
  case consuming
  /// The parameter is passed indirectly via inout.
  case `inout`
}

extension SwiftParameter {
  init(_ node: FunctionParameterSyntax, symbolTable: SwiftSymbolTable) throws {
    // Determine the convention. The default is by-value, but there are
    // specifiers on the type for other conventions (like `inout`).
    var type = node.type
    var convention = SwiftParameterConvention.byValue
    if let attributedType = type.as(AttributedTypeSyntax.self) {
      var sawUnknownSpecifier = false
      for specifier in attributedType.specifiers {
        guard case .simpleTypeSpecifier(let simple) = specifier else {
          sawUnknownSpecifier = true
          continue
        }

        switch simple.specifier.tokenKind {
        case .keyword(.consuming), .keyword(.__consuming), .keyword(.__owned):
          convention = .consuming
        case .keyword(.inout):
          convention = .inout
        default:
          sawUnknownSpecifier = true
          break
        }
      }

      // Ignore anything else in the attributed type.
      if !sawUnknownSpecifier && attributedType.attributes.isEmpty {
        type = attributedType.baseType
      }
    }
    self.convention = convention

    // Determine the type.
    self.type = try SwiftType(type, symbolTable: symbolTable)

    // FIXME: swift-syntax itself should have these utilities based on identifiers.
    if let secondName = node.secondName {
      self.argumentLabel = node.firstName.identifier?.name
      self.parameterName = secondName.identifier?.name
    } else {
      self.argumentLabel = node.firstName.identifier?.name
      self.parameterName = self.argumentLabel
    }
  }
}
