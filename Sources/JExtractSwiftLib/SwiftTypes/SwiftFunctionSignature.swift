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

enum SwiftGenericRequirement: Equatable {
  case inherits(SwiftType, SwiftType)
  case equals(SwiftType, SwiftType)
}

/// Provides a complete signature for a Swift function, which includes its
/// parameters and return type.
public struct SwiftFunctionSignature: Equatable {
  var selfParameter: SwiftSelfParameter?
  var parameters: [SwiftParameter]
  var result: SwiftResult
  var effectSpecifiers: [SwiftEffectSpecifier]
  var genericParameters: [SwiftGenericParameterDeclaration]
  var genericRequirements: [SwiftGenericRequirement]

  init(
    selfParameter: SwiftSelfParameter? = nil,
    parameters: [SwiftParameter],
    result: SwiftResult,
    effectSpecifiers: [SwiftEffectSpecifier],
    genericParameters: [SwiftGenericParameterDeclaration],
    genericRequirements: [SwiftGenericRequirement]
  ) {
    self.selfParameter = selfParameter
    self.parameters = parameters
    self.result = result
    self.effectSpecifiers = effectSpecifiers
    self.genericParameters = genericParameters
    self.genericRequirements = genericRequirements
  }
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
  init(
    _ node: InitializerDeclSyntax,
    enclosingType: SwiftType?,
    lookupContext: SwiftTypeLookupContext
  ) throws {
    guard let enclosingType else {
      throw SwiftFunctionTranslationError.missingEnclosingType(node)
    }

    let (genericParams, genericRequirements) = try Self.translateGenericParameters(
      parameterClause: node.genericParameterClause,
      whereClause: node.genericWhereClause,
      lookupContext: lookupContext
    )
    let (parameters, effectSpecifiers) = try Self.translateFunctionSignature(
      node.signature,
      lookupContext: lookupContext
    )

    let type = node.optionalMark != nil ? .optional(enclosingType) : enclosingType

    self.init(
      selfParameter: .initializer(enclosingType),
      parameters: parameters,
      result: SwiftResult(convention: .direct, type: type),
      effectSpecifiers: effectSpecifiers,
      genericParameters: genericParams,
      genericRequirements: genericRequirements
    )
  }

  init(
    _ node: EnumCaseElementSyntax,
    enclosingType: SwiftType,
    lookupContext: SwiftTypeLookupContext
  ) throws {
    let parameters = try node.parameterClause?.parameters.map { param in
      try SwiftParameter(param, lookupContext: lookupContext)
    }

    self.init(
      selfParameter: .initializer(enclosingType),
      parameters: parameters ?? [],
      result: SwiftResult(convention: .direct, type: enclosingType),
      effectSpecifiers: [],
      genericParameters: [],
      genericRequirements: []
    )
  }

  init(
    _ node: FunctionDeclSyntax,
    enclosingType: SwiftType?,
    lookupContext: SwiftTypeLookupContext
  ) throws {
    let (genericParams, genericRequirements) = try Self.translateGenericParameters(
      parameterClause: node.genericParameterClause,
      whereClause: node.genericWhereClause,
      lookupContext: lookupContext
    )

    // If this is a member of a type, so we will have a self parameter. Figure out the
    // type and convention for the self parameter.
    let selfParameter: SwiftSelfParameter?
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
        selfParameter = .staticMethod(enclosingType)
      } else {
        selfParameter = .instance(
          SwiftParameter(
            convention: isMutating ? .inout : isConsuming ? .consuming : .byValue,
            type: enclosingType
          )
        )
      }
    } else {
      selfParameter = nil
    }

    // Translate the parameters.
    let (parameters, effectSpecifiers) = try Self.translateFunctionSignature(
      node.signature,
      lookupContext: lookupContext
    )

    // Translate the result type.
    let result: SwiftResult
    if let resultType = node.signature.returnClause?.type {
      result = try SwiftResult(
        convention: .direct,
        type: SwiftType(resultType, lookupContext: lookupContext)
      )
    } else {
      result = .void
    }

    self.init(
      selfParameter: selfParameter,
      parameters: parameters,
      result: result,
      effectSpecifiers: effectSpecifiers,
      genericParameters: genericParams,
      genericRequirements: genericRequirements
    )
  }

  static func translateGenericParameters(
    parameterClause: GenericParameterClauseSyntax?,
    whereClause: GenericWhereClauseSyntax?,
    lookupContext: SwiftTypeLookupContext
  ) throws -> (parameters: [SwiftGenericParameterDeclaration], requirements: [SwiftGenericRequirement]) {
    var params: [SwiftGenericParameterDeclaration] = []
    var requirements: [SwiftGenericRequirement] = []

    // Parameter clause
    if let parameterClause {
      for parameterNode in parameterClause.parameters {
        guard parameterNode.specifier == nil else {
          throw SwiftFunctionTranslationError.genericParameterSpecifier(parameterNode)
        }
        let param = try lookupContext.typeDeclaration(for: parameterNode, sourceFilePath: "FIXME_HAS_NO_PATH.swift") as! SwiftGenericParameterDeclaration
        params.append(param)
        if let inheritedNode = parameterNode.inheritedType {
          let inherited = try SwiftType(inheritedNode, lookupContext: lookupContext)
          requirements.append(.inherits(.genericParameter(param), inherited))
        }
      }
    }

    // Where clause
    if let whereClause {
      for requirementNode in whereClause.requirements {
        let requirement: SwiftGenericRequirement
        switch requirementNode.requirement {
        case .conformanceRequirement(let conformance):
          requirement = .inherits(
            try SwiftType(conformance.leftType, lookupContext: lookupContext),
            try SwiftType(conformance.rightType, lookupContext: lookupContext)
          )
        case .sameTypeRequirement(let sameType):
          guard let leftType = sameType.leftType.as(TypeSyntax.self) else {
            throw SwiftFunctionTranslationError.expressionInGenericRequirement(requirementNode)
          }
          guard let rightType = sameType.rightType.as(TypeSyntax.self) else {
            throw SwiftFunctionTranslationError.expressionInGenericRequirement(requirementNode)
          }
          requirement = .equals(
            try SwiftType(leftType, lookupContext: lookupContext),
            try SwiftType(rightType, lookupContext: lookupContext)
            )
        case .layoutRequirement:
          throw SwiftFunctionTranslationError.layoutRequirement(requirementNode)
        }
        requirements.append(requirement)
      }
    }

    return (params, requirements)
  }

  /// Translate the function signature, returning the list of translated
  /// parameters and effect specifiers.
  static func translateFunctionSignature(
    _ signature: FunctionSignatureSyntax,
    lookupContext: SwiftTypeLookupContext
  ) throws -> ([SwiftParameter], [SwiftEffectSpecifier]) {
    var effectSpecifiers = [SwiftEffectSpecifier]()
    if signature.effectSpecifiers?.throwsClause != nil {
      effectSpecifiers.append(.throws)
    }
    if let asyncSpecifier = signature.effectSpecifiers?.asyncSpecifier {
      throw SwiftFunctionTranslationError.async(asyncSpecifier)
    }

    let parameters = try signature.parameterClause.parameters.map { param in
      try SwiftParameter(param, lookupContext: lookupContext)
    }

    return (parameters, effectSpecifiers)
  }

  init(
    _ varNode: VariableDeclSyntax,
    isSet: Bool,
    enclosingType: SwiftType?,
    lookupContext: SwiftTypeLookupContext
  ) throws {

    // If this is a member of a type, so we will have a self parameter. Figure out the
    // type and convention for the self parameter.
    if let enclosingType {
      var isStatic = false
      for modifier in varNode.modifiers {
        switch modifier.name.tokenKind {
        case .keyword(.static): isStatic = true
        case .keyword(.class): throw SwiftFunctionTranslationError.classMethod(modifier.name)
        default: break
        }
      }

      if isStatic {
        self.selfParameter = .staticMethod(enclosingType)
      } else {
        self.selfParameter = .instance(
          SwiftParameter(
            convention: isSet && !enclosingType.isReferenceType ? .inout : .byValue,
            type: enclosingType
          )
        )
      }
    } else {
      self.selfParameter = nil
    }

    guard let binding = varNode.bindings.first, varNode.bindings.count == 1 else {
      throw SwiftFunctionTranslationError.multipleBindings(varNode)
    }

    guard let varTypeNode = binding.typeAnnotation?.type else {
      throw SwiftFunctionTranslationError.missingTypeAnnotation(varNode)
    }
    let valueType = try SwiftType(varTypeNode, lookupContext: lookupContext)

    var effectSpecifiers: [SwiftEffectSpecifier]? = nil
    switch binding.accessorBlock?.accessors {
    case .getter(let getter):
      if let getter = getter.as(AccessorDeclSyntax.self) {
        effectSpecifiers = try Self.effectSpecifiers(from: getter)
      }
    case .accessors(let accessors):
      if let getter = accessors.first(where: { $0.accessorSpecifier.tokenKind == .keyword(.get) }) {
        effectSpecifiers = try Self.effectSpecifiers(from: getter)
      }
    default:
      break
    }

    self.effectSpecifiers = effectSpecifiers ?? []

    if isSet {
      self.parameters = [SwiftParameter(convention: .byValue, parameterName: "newValue", type: valueType)]
      self.result = .void
    } else {
      self.parameters = []
      self.result = .init(convention: .direct, type: valueType)
    }
    self.genericParameters = []
    self.genericRequirements = []
  }

  private static func effectSpecifiers(from decl: AccessorDeclSyntax) throws -> [SwiftEffectSpecifier] {
    var effectSpecifiers = [SwiftEffectSpecifier]()
    if decl.effectSpecifiers?.throwsClause != nil {
      effectSpecifiers.append(.throws)
    }
    if let asyncSpecifier = decl.effectSpecifiers?.asyncSpecifier {
      throw SwiftFunctionTranslationError.async(asyncSpecifier)
    }
    return effectSpecifiers
  }
}

extension VariableDeclSyntax {
  struct SupportedAccessorKinds: OptionSet {
    var rawValue: UInt8

    static var get: Self = .init(rawValue: 1 << 0)
    static var set: Self = .init(rawValue: 1 << 1)
  }

  /// Determine what operations (i.e. get and/or set) supported in this `VariableDeclSyntax`
  ///
  /// - Parameters:
  ///   - binding the pattern binding in this declaration.
  func supportedAccessorKinds(binding: PatternBindingSyntax) -> SupportedAccessorKinds {
    if self.bindingSpecifier.tokenKind == .keyword(.let) {
      return [.get]
    }

    if let accessorBlock = binding.accessorBlock {
      switch accessorBlock.accessors {
      case .getter:
        return [.get]
      case .accessors(let accessors):
        for accessor in accessors {
          switch accessor.accessorSpecifier.tokenKind {
            // Existence of any write accessor or observer implies this supports read/write.
          case .keyword(.set), .keyword(._modify), .keyword(.unsafeMutableAddress),
              .keyword(.willSet), .keyword(.didSet):
            return [.get, .set]
          default: // Ignore willSet/didSet and unknown accessors.
            break
          }
        }
        return [.get]
      }
    }

    return [.get, .set]
  }
}

enum SwiftFunctionTranslationError: Error {
  case `throws`(ThrowsClauseSyntax)
  case async(TokenSyntax)
  case classMethod(TokenSyntax)
  case missingEnclosingType(InitializerDeclSyntax)
  case failableInitializer(InitializerDeclSyntax)
  case multipleBindings(VariableDeclSyntax)
  case missingTypeAnnotation(VariableDeclSyntax)
  case unsupportedAccessor(AccessorDeclSyntax)
  case genericParameterSpecifier(GenericParameterSyntax)
  case expressionInGenericRequirement(GenericRequirementSyntax)
  case layoutRequirement(GenericRequirementSyntax)
}
