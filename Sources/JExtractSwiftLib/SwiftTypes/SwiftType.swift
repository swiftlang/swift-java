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
  case nominal(SwiftNominalType)

  indirect case function(SwiftFunctionType)

  /// `<type>.Type`
  indirect case metatype(SwiftType)

  /// `<type>?`
  indirect case optional(SwiftType)

  /// `(<type>, <type>)`
  case tuple([SwiftType])

  /// `any <type>`
  indirect case existential(SwiftType)

  /// `some <type>`
  indirect case opaque(SwiftType)

  static var void: Self {
    return .tuple([])
  }

  var asNominalType: SwiftNominalType? {
    switch self {
    case .nominal(let nominal): nominal
    case .tuple(let elements): elements.count == 1 ? elements[0].asNominalType : nil
    case .function, .metatype, .optional, .existential, .opaque: nil
    }
  }

  var asNominalTypeDeclaration: SwiftNominalTypeDeclaration? {
    asNominalType?.nominalTypeDecl
  }

  /// Whether this is the "Void" type, which is actually an empty tuple.
  var isVoid: Bool {
    switch self {
    case .tuple([]):
      return true
    case .nominal(let nominal):
      return nominal.parent == nil && nominal.nominalTypeDecl.moduleName == "Swift" && nominal.nominalTypeDecl.name == "Void"
    default:
      return false
    }
  }

  /// Whether this is a pointer type. I.e 'Unsafe[Mutable][Raw]Pointer'
  var isPointer: Bool {
    switch self {
    case .nominal(let nominal):
      if let knownType = nominal.nominalTypeDecl.knownTypeKind {
        return knownType.isPointer
      }
    default:
      break
    }
    return false;
  }

  /// Reference type
  ///
  ///  * Mutations don't require 'inout' convention.
  ///  * The value is a pointer of the instance data,
  var isReferenceType: Bool {
    switch self {
    case .nominal(let nominal):
      return nominal.nominalTypeDecl.isReferenceType
    case .metatype, .function:
      return true
    case .optional, .tuple, .existential, .opaque:
      return false
    }
  }
}

extension SwiftType: CustomStringConvertible {
  /// Whether forming a postfix type or expression to this Swift type
  /// requires parentheses.
  private var postfixRequiresParentheses: Bool {
    switch self {
    case .function, .existential, .opaque: true
    case .metatype, .nominal, .optional, .tuple: false
    }
  }

  var description: String {
    switch self {
    case .nominal(let nominal): return nominal.description
    case .function(let functionType): return functionType.description
    case .metatype(let instanceType):
      var instanceTypeStr = instanceType.description
      if instanceType.postfixRequiresParentheses {
        instanceTypeStr = "(\(instanceTypeStr))"
      }
      return "\(instanceTypeStr).Type"
    case .optional(let wrappedType):
      return "\(wrappedType.description)?"
    case .tuple(let elements):
      return "(\(elements.map(\.description).joined(separator: ", ")))"
    case .existential(let constraintType):
      return "any \(constraintType)"
    case .opaque(let constraintType):
      return "some \(constraintType)"
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
    self.storedParent = parent.map { .nominal($0) } ?? nominalTypeDecl.parent.map { .nominal(SwiftNominalType(nominalTypeDecl: $0)) }
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
        .packElementType, .packExpansionType, .suppressedType:
      throw TypeTranslationError.unimplementedType(type)

    case .attributedType(let attributedType):
      // Only recognize the "@convention(c)" and "@convention(swift)" attributes, and
      // then only on function types.
      // FIXME: This string matching is a horrible hack.
      switch attributedType.attributes.trimmedDescription {
      case "@convention(c)", "@convention(swift)":
        let innerType = try SwiftType(attributedType.baseType, symbolTable: symbolTable)
        switch innerType {
        case .function(var functionType):
          let isConventionC = attributedType.attributes.trimmedDescription == "@convention(c)"
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
          switch argument.argument {
          case .type(let argumentTy):
            try SwiftType(argumentTy, symbolTable: symbolTable)
          default:
            throw TypeTranslationError.unimplementedType(type)
          }
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
          switch argument.argument {
          case .type(let argumentTy):
            try SwiftType(argumentTy, symbolTable: symbolTable)
          default:
            throw TypeTranslationError.unimplementedType(type)
          }
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

    case .someOrAnyType(let someOrAntType):
      if someOrAntType.someOrAnySpecifier.tokenKind == .keyword(.some) {
        self = .opaque(try SwiftType(someOrAntType.constraint, symbolTable: symbolTable))
      } else {
        self = .opaque(try SwiftType(someOrAntType.constraint, symbolTable: symbolTable))
      }
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

  init?(
    nominalDecl: NamedDeclSyntax & DeclGroupSyntax,
    parent: SwiftType?,
    symbolTable: SwiftSymbolTable
  ) {
    guard let nominalTypeDecl = symbolTable.lookupType(
      nominalDecl.name.text,
      parent: parent?.asNominalTypeDeclaration
    ) else {
      return nil
    }

    self = .nominal(
      SwiftNominalType(
        parent: parent?.asNominalType,
        nominalTypeDecl: nominalTypeDecl,
        genericArguments: nil
      )
    )
  }

  /// Produce an expression that creates the metatype for this type in
  /// Swift source code.
  var metatypeReferenceExprSyntax: ExprSyntax {
    let type: ExprSyntax = "\(raw: description)"
    if postfixRequiresParentheses {
      return "(\(type)).self"
    }
    return "\(type).self"
  }
}

enum TypeTranslationError: Error {
  /// We haven't yet implemented support for this type.
  case unimplementedType(TypeSyntax)

  /// Missing generic arguments.
  case missingGenericArguments(TypeSyntax)

  /// Unknown nominal type.
  case unknown(TypeSyntax)
}
