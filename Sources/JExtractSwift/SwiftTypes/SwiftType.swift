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

/// Describes a type in the Swift type system.
enum SwiftType: Equatable {
  indirect case function(SwiftFunctionType)
  indirect case metatype(SwiftType)
  case nominal(SwiftNominalType)
  indirect case optional(SwiftType)
  case tuple([SwiftType])

  var asNominalType: SwiftNominalType? {
    switch self {
    case .nominal(let nominal): nominal
    case .tuple(let elements): elements.count == 1 ? elements[0].asNominalType : nil
    case .function, .metatype, .optional: nil
    }
  }

  var asNominalTypeDeclaration: SwiftNominalTypeDeclaration? {
    asNominalType?.nominalTypeDecl
  }
}

extension SwiftType: CustomStringConvertible {
  var description: String {
    switch self {
    case .nominal(let nominal): return nominal.description
    case .function(let functionType): return functionType.description
    case .metatype(let instanceType):
      return "(\(instanceType.description)).Type"
    case .optional(let wrappedType):
      return "\(wrappedType.description)?"
    case .tuple(let elements):
      return "(\(elements.map(\.description).joined(separator: ", ")))"
    }
  }
}

struct SwiftNominalType: Equatable {
  enum Parent: Equatable {
    indirect case nominal(SwiftNominalType)
  }

  private var storedParent: Parent?
  var nominalTypeDecl: SwiftNominalTypeDeclaration
  var genericArguments: [SwiftType]?

  init(
    parent: SwiftNominalType? = nil,
    nominalTypeDecl: SwiftNominalTypeDeclaration,
    genericArguments: [SwiftType]? = nil
  ) {
    self.storedParent = parent.map { .nominal($0) }
    self.nominalTypeDecl = nominalTypeDecl
    self.genericArguments = genericArguments
  }

  var parent: SwiftNominalType? {
    if case .nominal(let parent) = storedParent ?? .none {
      return parent
    }

    return nil
  }
}

extension SwiftNominalType: CustomStringConvertible {
  var description: String {
    var resultString: String
    if let parent {
      resultString = parent.description + "."
    } else {
      resultString = ""
    }

    resultString += nominalTypeDecl.name

    if let genericArguments {
      resultString += "<\(genericArguments.map(\.description).joined(separator: ", "))>"
    }

    return resultString
  }
}

extension SwiftType {
  init(_ type: TypeSyntax, symbolTable: SwiftSymbolTable) throws {
    switch type.as(TypeSyntaxEnum.self) {
    case .arrayType, .classRestrictionType, .compositionType,
        .dictionaryType, .missingType, .namedOpaqueReturnType,
        .packElementType, .packExpansionType, .someOrAnyType,
        .suppressedType:
      throw TypeTranslationError.unimplementedType(type)

    case .attributedType(let attributedType):
      // Only recognize the "@convention(c)" and "@convention(swift)" attributes, and
      // then only on function types.
      // FIXME: This string matching is a horrible hack.
      switch attributedType.trimmedDescription {
      case "@convention(c)", "@convention(swift)":
        let innerType = try SwiftType(attributedType.baseType, symbolTable: symbolTable)
        switch innerType {
        case .function(var functionType):
          let isConventionC = attributedType.trimmedDescription == "@convention(c)"
          let convention: SwiftFunctionType.Convention = isConventionC ? .c : .swift
          functionType.convention = convention
          self = .function(functionType)
        default:
          throw TypeTranslationError.unimplementedType(type)
        }
      default:
        throw TypeTranslationError.unimplementedType(type)
      }

    case .functionType(let functionType):
      self = .function(
        try SwiftFunctionType(functionType, convention: .swift, symbolTable: symbolTable)
      )

    case .identifierType(let identifierType):
      // Translate the generic arguments.
      let genericArgs = try identifierType.genericArgumentClause.map { genericArgumentClause in
        try genericArgumentClause.arguments.map { argument in
          try SwiftType(argument.argument, symbolTable: symbolTable)
        }
      }

      // Resolve the type by name.
      self = try SwiftType(
        originalType: type,
        parent: nil,
        name: identifierType.name.text,
        genericArguments: genericArgs,
        symbolTable: symbolTable
      )

    case .implicitlyUnwrappedOptionalType(let optionalType):
      self = .optional(try SwiftType(optionalType.wrappedType, symbolTable: symbolTable))

    case .memberType(let memberType):
      // If the parent type isn't a known module, translate it.
      // FIXME: Need a more reasonable notion of which names are module names
      // for this to work. What can we query for this information?
      let parentType: SwiftType?
      if memberType.baseType.trimmedDescription == "Swift" {
        parentType = nil
      } else {
        parentType = try SwiftType(memberType.baseType, symbolTable: symbolTable)
      }

      // Translate the generic arguments.
      let genericArgs = try memberType.genericArgumentClause.map { genericArgumentClause in
        try genericArgumentClause.arguments.map { argument in
          try SwiftType(argument.argument, symbolTable: symbolTable)
        }
      }

      self = try SwiftType(
        originalType: type,
        parent: parentType,
        name: memberType.name.text,
        genericArguments: genericArgs,
        symbolTable: symbolTable
      )

    case .metatypeType(let metatypeType):
      self = .metatype(try SwiftType(metatypeType.baseType, symbolTable: symbolTable))

    case .optionalType(let optionalType):
      self = .optional(try SwiftType(optionalType.wrappedType, symbolTable: symbolTable))

    case .tupleType(let tupleType):
      self = try .tuple(tupleType.elements.map { element in
         try SwiftType(element.type, symbolTable: symbolTable)
      })
    }
  }

  init(
    originalType: TypeSyntax,
    parent: SwiftType?,
    name: String,
    genericArguments: [SwiftType]?,
    symbolTable: SwiftSymbolTable
  ) throws {
    // Look up the imported types by name to resolve it to a nominal type.
    guard let nominalTypeDecl = symbolTable.lookupType(
      name,
      parent: parent?.asNominalTypeDeclaration
    ) else {
      throw TypeTranslationError.unknown(originalType)
    }

    self = .nominal(
      SwiftNominalType(
        parent: parent?.asNominalType,
        nominalTypeDecl: nominalTypeDecl,
        genericArguments: genericArguments
      )
    )
  }
}
