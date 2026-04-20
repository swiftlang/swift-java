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

/// An element of a Swift tuple type, preserving the optional label.
struct SwiftTupleElement: Equatable, CustomStringConvertible {
  var label: String?
  var type: SwiftType

  var description: String {
    if let label {
      return "\(label): \(type)"
    }
    return "\(type)"
  }
}

/// Describes a type in the Swift type system.
enum SwiftType: Equatable {
  case nominal(SwiftNominalType)

  case genericParameter(SwiftGenericParameterDeclaration)

  indirect case function(SwiftFunctionType)

  /// `<type>.Type`
  indirect case metatype(SwiftType)

  /// `(<label>: <type>, <label>: <type>)`
  case tuple([SwiftTupleElement])

  /// `any <type>`
  indirect case existential(SwiftType)

  /// `some <type>`
  indirect case opaque(SwiftType)

  /// `type1` & `type2`
  indirect case composite([SwiftType])

  static var void: Self {
    .tuple([])
  }

  var asNominalType: SwiftNominalType? {
    switch self {
    case .nominal(let nominal): nominal
    case .tuple(let elements): elements.count == 1 ? elements[0].type.asNominalType : nil
    case .genericParameter, .function, .metatype, .existential, .opaque, .composite: nil
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
      return nominal.parent == nil && nominal.nominalTypeDecl.moduleName == "Swift"
        && nominal.nominalTypeDecl.name == "Void"
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
    return false
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
    case .genericParameter, .tuple, .existential, .opaque, .composite:
      return false
    }
  }

  var isUnsignedInteger: Bool {
    switch self {
    case .nominal(let nominal):
      switch nominal.nominalTypeDecl.knownTypeKind {
      case .uint8, .uint16, .uint32, .uint64, .uint: true
      default: false
      }
    default: false
    }
  }

  var isArchDependingInteger: Bool {
    switch self {
    case .nominal(let nominal):
      switch nominal.nominalTypeDecl.knownTypeKind {
      case .int, .uint: true
      default: false
      }
    default: false
    }
  }

  var isRawTypeCompatible: Bool {
    switch self {
    case .nominal(let nominal):
      switch nominal.nominalTypeDecl.knownTypeKind {
      case .int, .uint, .int8, .uint8, .int16, .uint16, .int32, .uint32, .int64, .uint64, .float, .double, .string:
        true
      default:
        false
      }
    default: false
    }
  }
}

extension SwiftType: CustomStringConvertible {
  /// Whether forming a postfix type or expression to this Swift type
  /// requires parentheses.
  private var postfixRequiresParentheses: Bool {
    switch self {
    case .function, .existential, .opaque, .composite: true
    case .genericParameter, .metatype, .nominal, .tuple: false
    }
  }

  var description: String {
    switch self {
    case .nominal(let nominal): return nominal.description
    case .genericParameter(let genericParam): return genericParam.name
    case .function(let functionType): return functionType.description
    case .metatype(let instanceType):
      var instanceTypeStr = instanceType.description
      if instanceType.postfixRequiresParentheses {
        instanceTypeStr = "(\(instanceTypeStr))"
      }
      return "\(instanceTypeStr).Type"
    case .tuple(let elements):
      return "(\(elements.map(\.description).joined(separator: ", ")))"
    case .existential(let constraintType):
      switch constraintType {
      case .composite:
        return "any (\(constraintType))"
      default:
        return "any \(constraintType)"
      }
    case .opaque(let constraintType):
      switch constraintType {
      case .composite:
        return "some (\(constraintType))"
      default:
        return "some \(constraintType)"
      }
    case .composite(let types):
      return types.map(\.description).joined(separator: " & ")
    }
  }
}

struct SwiftNominalType: Equatable {
  indirect enum Parent: Equatable {
    case nominal(SwiftNominalType)
  }

  enum SugarName: Equatable {
    case optional
    case array
    case dictionary
  }

  private var storedParent: Parent?
  var sugarName: SugarName?
  var nominalTypeDecl: SwiftNominalTypeDeclaration
  var genericArguments: [SwiftType]?

  init(
    parent: SwiftNominalType? = nil,
    sugarName: SugarName? = nil,
    nominalTypeDecl: SwiftNominalTypeDeclaration,
    genericArguments: [SwiftType]? = nil
  ) {
    self.storedParent =
      parent.map { .nominal($0) } ?? nominalTypeDecl.parent.map { .nominal(SwiftNominalType(nominalTypeDecl: $0)) }
    self.sugarName = sugarName
    self.nominalTypeDecl = nominalTypeDecl
    self.genericArguments = genericArguments
  }

  var parent: SwiftNominalType? {
    if case .nominal(let parent) = storedParent ?? .none {
      return parent
    }

    return nil
  }

  package var asKnownType: SwiftKnownType? {
    nominalTypeDecl.knownTypeKind.flatMap {
      SwiftKnownType(kind: $0, genericArguments: genericArguments)
    }
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

    switch sugarName {
    case .none:
      resultString += nominalTypeDecl.name
      if let genericArguments {
        resultString += "<\(genericArguments.map(\.description).joined(separator: ", "))>"
      }
    case .some(.optional):
      resultString += "\(genericArguments![0])?"
    case .some(.array):
      resultString += "[\(genericArguments![0])]"
    case .some(.dictionary):
      resultString += "[\(genericArguments![0]): \(genericArguments![1])]"
    }

    return resultString
  }
}

extension SwiftNominalType.Parent: CustomStringConvertible {
  var description: String {
    switch self {
    case .nominal(let nominal):
      return nominal.description
    }
  }
}

extension SwiftNominalType {
  var isSwiftJavaWrapper: Bool {
    nominalTypeDecl.syntax?.attributes.contains(where: \.isSwiftJavaMacro) ?? false
  }

  var isProtocol: Bool {
    nominalTypeDecl.kind == .protocol
  }
}

extension SwiftType {
  init(_ type: TypeSyntax, lookupContext: SwiftTypeLookupContext) throws {
    var knownTypes: SwiftKnownTypes {
      SwiftKnownTypes(symbolTable: lookupContext.symbolTable)
    }

    switch type.as(TypeSyntaxEnum.self) {
    case .classRestrictionType,
      .missingType, .namedOpaqueReturnType,
      .packElementType, .packExpansionType, .suppressedType, .inlineArrayType:
      throw TypeTranslationError.unimplementedType(type)

    case .attributedType(let attributedType):
      // Recognize "@convention(c)", "@convention(swift)", and "@escaping" attributes on function types.
      // FIXME: This string matching is a horrible hack.
      let attrs = attributedType.attributes.trimmedDescription

      // Handle @escaping attribute
      if attrs.contains("@escaping") {
        let innerType = try SwiftType(attributedType.baseType, lookupContext: lookupContext)
        switch innerType {
        case .function(var functionType):
          functionType.isEscaping = true
          self = .function(functionType)
        default:
          throw TypeTranslationError.unimplementedType(type)
        }
      } else {
        // Handle @convention attributes
        switch attrs {
        case "@convention(c)", "@convention(swift)":
          let innerType = try SwiftType(attributedType.baseType, lookupContext: lookupContext)
          switch innerType {
          case .function(var functionType):
            let isConventionC = attrs == "@convention(c)"
            let convention: SwiftFunctionType.Convention = isConventionC ? .c : .swift
            functionType.convention = convention
            self = .function(functionType)
          default:
            throw TypeTranslationError.unimplementedType(type)
          }
        default:
          throw TypeTranslationError.unimplementedType(type)
        }
      }

    case .functionType(let functionType):
      self = .function(
        try SwiftFunctionType(functionType, convention: .swift, lookupContext: lookupContext)
      )

    case .identifierType(let identifierType):
      // Translate the generic arguments.
      let genericArgs = try identifierType.genericArgumentClause.map { genericArgumentClause in
        try genericArgumentClause.arguments.map { argument in
          switch argument.argument {
          case .type(let argumentTy):
            try SwiftType(argumentTy, lookupContext: lookupContext)
          default:
            throw TypeTranslationError.unimplementedType(type)
          }
        }
      }

      // Resolve the type by name.
      self = try SwiftType(
        originalType: type,
        parent: nil,
        name: identifierType.name,
        genericArguments: genericArgs,
        lookupContext: lookupContext
      )

    case .implicitlyUnwrappedOptionalType(let optionalType):
      self = knownTypes.optionalSugar(try SwiftType(optionalType.wrappedType, lookupContext: lookupContext))

    case .memberType(let memberType):
      // If the parent type is a known module name, perform a module-qualified
      // lookup instead of treating the module as a parent type
      let parentType: SwiftType?
      let moduleName: String?
      if let base = memberType.baseType.as(IdentifierTypeSyntax.self),
        lookupContext.symbolTable.isModuleName(base.name.trimmedDescription)
      {
        parentType = nil
        moduleName = base.name.trimmedDescription
      } else {
        parentType = try SwiftType(memberType.baseType, lookupContext: lookupContext)
        moduleName = nil
      }

      // Translate the generic arguments.
      let genericArgs = try memberType.genericArgumentClause.map { genericArgumentClause in
        try genericArgumentClause.arguments.map { argument in
          switch argument.argument {
          case .type(let argumentTy):
            try SwiftType(argumentTy, lookupContext: lookupContext)
          default:
            throw TypeTranslationError.unimplementedType(type)
          }
        }
      }

      self = try SwiftType(
        originalType: type,
        parent: parentType,
        name: memberType.name,
        genericArguments: genericArgs,
        lookupContext: lookupContext,
        module: moduleName
      )

    case .metatypeType(let metatypeType):
      self = .metatype(try SwiftType(metatypeType.baseType, lookupContext: lookupContext))

    case .optionalType(let optionalType):
      self = knownTypes.optionalSugar(try SwiftType(optionalType.wrappedType, lookupContext: lookupContext))

    case .tupleType(let tupleType):
      self = try .tuple(
        tupleType.elements.map { element in
          SwiftTupleElement(
            label: element.firstName?.text,
            type: try SwiftType(element.type, lookupContext: lookupContext)
          )
        }
      )

    case .someOrAnyType(let someOrAntType):
      if someOrAntType.someOrAnySpecifier.tokenKind == .keyword(.some) {
        self = .opaque(try SwiftType(someOrAntType.constraint, lookupContext: lookupContext))
      } else {
        self = .opaque(try SwiftType(someOrAntType.constraint, lookupContext: lookupContext))
      }

    case .compositionType(let compositeType):
      let types = try compositeType.elements.map {
        try SwiftType($0.type, lookupContext: lookupContext)
      }

      self = .composite(types)

    case .arrayType(let arrayType):
      let elementType = try SwiftType(arrayType.element, lookupContext: lookupContext)
      self = knownTypes.arraySugar(elementType)

    case .dictionaryType(let dictType):
      let keyType = try SwiftType(dictType.key, lookupContext: lookupContext)
      let valueType = try SwiftType(dictType.value, lookupContext: lookupContext)
      self = knownTypes.dictionarySugar(keyType, valueType)
    }
  }

  init(
    originalType: TypeSyntax,
    parent: SwiftType?,
    name: TokenSyntax,
    genericArguments: [SwiftType]?,
    lookupContext: SwiftTypeLookupContext,
    module: String? = nil
  ) throws {
    // Look up the imported types by name to resolve it to a nominal type.
    let typeDecl: SwiftTypeDeclaration?
    if let parent {
      guard let parentDecl = parent.asNominalTypeDeclaration else {
        throw TypeTranslationError.unknown(originalType)
      }
      typeDecl = lookupContext.symbolTable.lookupNestedType(name.text, parent: parentDecl)
    } else if let module {
      typeDecl = lookupContext.moduleQualifiedLookup(name: name.text, in: module)
    } else {
      guard let ident = Identifier(name) else {
        throw TypeTranslationError.unknown(originalType)
      }
      typeDecl = try lookupContext.unqualifiedLookup(name: ident, from: name)
    }
    guard let typeDecl else {
      throw TypeTranslationError.unknown(originalType)
    }

    if let nominalDecl = typeDecl as? SwiftNominalTypeDeclaration {
      self = .nominal(
        SwiftNominalType(
          parent: parent?.asNominalType,
          nominalTypeDecl: nominalDecl,
          genericArguments: genericArguments
        )
      )
    } else if let genericParamDecl = typeDecl as? SwiftGenericParameterDeclaration {
      self = .genericParameter(genericParamDecl)
    } else if let aliasDecl = typeDecl as? SwiftTypeAliasDeclaration {
      let aliasGenericParams =
        aliasDecl.syntax.genericParameterClause?.parameters.map { $0.name.text } ?? []
      let useSiteArgs = genericArguments ?? []

      // The alias's generic parameter count must match the use-site argument
      // count. Treat any mismatch (including use-site args on a non-generic
      // alias, or missing args on a generic alias) as unimplemented to fall
      // through to silent drop.
      guard aliasGenericParams.count == useSiteArgs.count else {
        throw TypeTranslationError.unimplementedType(originalType)
      }

      let resolved = try lookupContext.resolve(typeAlias: aliasDecl)

      if aliasGenericParams.isEmpty {
        self = resolved
      } else {
        let substitutions = Dictionary(
          uniqueKeysWithValues: zip(aliasGenericParams, useSiteArgs)
        )
        self = resolved.substituting(genericParameters: substitutions)
      }
    } else {
      fatalError("unknown SwiftTypeDeclaration: \(type(of: typeDecl))")
    }
  }

  init?(
    nominalDecl: NamedDeclSyntax & DeclGroupSyntax,
    parent: SwiftType?,
    symbolTable: SwiftSymbolTable
  ) {
    guard
      let nominalTypeDecl = symbolTable.lookupType(
        nominalDecl.name.text,
        parent: parent?.asNominalTypeDeclaration
      )
    else {
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

  /// Substitute generic parameters *by name*.
  ///
  /// This is used e.g. by typealiases like `typealias Ano<T> = Array<T>`,
  /// so usages like `Ano<Int>` become `Array<Int>`.
  func substituting(genericParameters substitutions: [String: SwiftType]) -> SwiftType {
    guard !substitutions.isEmpty else { return self }

    switch self {
    case .nominal(let nominal):
      return .nominal(
        SwiftNominalType(
          parent: nominal.parent,
          sugarName: nominal.sugarName,
          nominalTypeDecl: nominal.nominalTypeDecl,
          genericArguments: nominal.genericArguments?.map {
            $0.substituting(genericParameters: substitutions)
          }
        )
      )
    case .genericParameter(let decl):
      return substitutions[decl.name] ?? self
    case .function(var fn):
      fn.parameters = fn.parameters.map { p in
        var p = p
        p.type = p.type.substituting(genericParameters: substitutions)
        return p
      }
      fn.resultType = fn.resultType.substituting(genericParameters: substitutions)
      return .function(fn)
    case .metatype(let inner):
      return .metatype(inner.substituting(genericParameters: substitutions))
    case .tuple(let elements):
      return .tuple(
        elements.map {
          SwiftTupleElement(
            label: $0.label,
            type: $0.type.substituting(genericParameters: substitutions)
          )
        }
      )
    case .existential(let inner):
      return .existential(inner.substituting(genericParameters: substitutions))
    case .opaque(let inner):
      return .opaque(inner.substituting(genericParameters: substitutions))
    case .composite(let types):
      return .composite(types.map { $0.substituting(genericParameters: substitutions) })
    }
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
  case unimplementedType(TypeSyntax, file: StaticString = #file, line: Int = #line)

  /// Missing generic arguments.
  case missingGenericArguments(TypeSyntax, file: StaticString = #file, line: Int = #line)

  /// Unknown nominal type.
  case unknown(TypeSyntax, file: StaticString = #file, line: Int = #line)
}
