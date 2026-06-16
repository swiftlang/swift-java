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

public struct SwiftParameter: Equatable {
  public var convention: SwiftParameterConvention
  public var argumentLabel: String?
  public var parameterName: String?
  public var type: SwiftType

  /// Whether this is a variadic parameter (`T...`).
  public var isVariadic: Bool
  /// Whether the parameter declares a default value.
  public var hasDefaultValue: Bool
  /// The default-value expression source, if any (e.g. `42`, `[]`).
  public var defaultValueExpression: String?

  public init(
    convention: SwiftParameterConvention,
    argumentLabel: String? = nil,
    parameterName: String? = nil,
    type: SwiftType,
    isVariadic: Bool = false,
    hasDefaultValue: Bool = false,
    defaultValueExpression: String? = nil
  ) {
    self.convention = convention
    self.argumentLabel = argumentLabel
    self.parameterName = parameterName
    self.type = type
    self.isVariadic = isVariadic
    self.hasDefaultValue = hasDefaultValue
    self.defaultValueExpression = defaultValueExpression
  }

  /// The simple parameter name, falling back to the argument label.
  public var name: String {
    parameterName ?? argumentLabel ?? "_"
  }

  /// The external argument label, falling back to the parameter name.
  public var effectiveLabel: String {
    argumentLabel ?? name
  }

  /// Whether this parameter is passed `inout`.
  public var isInout: Bool {
    convention == .inout
  }
}

extension SwiftParameter: CustomStringConvertible {
  public var description: String {
    let argumentLabel = self.argumentLabel ?? "_"
    let parameterName = self.parameterName ?? "_"

    return "\(argumentLabel) \(parameterName): \(descriptionInType)"
  }

  public var descriptionInType: String {
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
public enum SwiftParameterConvention: Equatable {
  /// The parameter is passed by-value or borrowed.
  case byValue
  /// The parameter is passed by-value but consumed.
  case consuming
  /// The parameter is passed indirectly via inout.
  case `inout`
}

extension SwiftParameter {
  public init(_ node: EnumCaseParameterSyntax, lookupContext: SwiftTypeLookupContext) throws {
    self.convention = .byValue
    self.type = try SwiftType(node.type, lookupContext: lookupContext)
    self.argumentLabel = nil
    self.parameterName = node.firstName?.identifier?.name
    self.argumentLabel = node.firstName?.identifier?.name
    self.isVariadic = false
    self.hasDefaultValue = node.defaultValue != nil
    self.defaultValueExpression = node.defaultValue?.value.trimmedDescription
  }
}

extension SwiftParameter {
  public init(_ node: FunctionParameterSyntax, lookupContext: SwiftTypeLookupContext) throws {
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
    self.type = try SwiftType(type, lookupContext: lookupContext)

    // Variadic / default-value information.
    self.isVariadic = node.ellipsis != nil
    self.hasDefaultValue = node.defaultValue != nil
    self.defaultValueExpression = node.defaultValue?.value.trimmedDescription

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
