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

/// Any extracted Swift declaration
public protocol ExtractedSwiftDecl: AnyObject {}

public enum SwiftAPIKind: Equatable {
  case function
  case initializer
  case getter
  case setter
  case enumCase
  case subscriptGetter
  case subscriptSetter
  case `operator`
}

/// Describes a Swift nominal type (e.g., a class, struct, enum) that has been
/// extracted by the analyzer for a downstream language target.
///
/// When `base` is non-nil, this is a specialization of a generic type
/// (e.g. `FishBox` specializing `Box<Element>` with `Element` = `Fish`).
/// The specialization delegates its member collections to the base type
/// so that extensions discovered later are visible through all specializations.
public final class ExtractedNominalType: ExtractedSwiftDecl {
  public let swiftNominal: SwiftNominalTypeDeclaration

  /// If this type is a specialization (FishTank), it points at the Tank base type of the specialization
  public let specializationBaseType: ExtractedNominalType?

  // The short path from module root to the file in which this nominal was originally declared.
  // E.g. for `Sources/Example/My/Types.swift` it would be `My/Types.swift`.
  public var sourceFilePath: String {
    self.swiftNominal.sourceFilePath
  }

  // Backing storage for member collections
  public var initializers: [ExtractedFunc] = []
  public var methods: [ExtractedFunc] = []
  public var variables: [ExtractedFunc] = []
  public var cases: [ExtractedEnumCase] = []
  public var inheritedTypes: [SwiftType]
  public var parent: SwiftNominalTypeDeclaration?

  /// The Swift base type name, e.g. "Box" — always the unparameterized name
  public var baseTypeName: String { swiftNominal.qualifiedName }

  /// The specialized output-facing name, e.g. "FishBox" — nil for base types
  public private(set) var specializedTypeName: String?

  /// Whether this type is a specialization of a generic type
  public var isSpecialization: Bool { specializationBaseType != nil }

  /// Generic parameter names (e.g. ["Element"] for Box<Element>). Empty for non-generic types
  public var genericParameterNames: [String] {
    swiftNominal.genericParameters.map(\.name)
  }

  /// Generic parameter declarations (e.g. `[Element]` for `Box<Element>`).
  /// Empty for non-generic types.
  public var genericParameters: [SwiftGenericParameterDeclaration] {
    swiftNominal.genericParameters
  }

  /// Maps generic parameter -> concrete type argument. Empty for unspecialized types
  /// e.g. {"Element": "Fish"} for FishBox
  public var genericArguments: [String: String] = [:]

  /// True when all generic parameters have corresponding arguments
  public var isFullySpecialized: Bool {
    !genericParameterNames.isEmpty && genericParameterNames.allSatisfy { genericArguments.keys.contains($0) }
  }

  public init(swiftNominal: SwiftNominalTypeDeclaration, lookupContext: SwiftTypeLookupContext) throws {
    self.swiftNominal = swiftNominal
    self.specializationBaseType = nil
    self.inheritedTypes =
      swiftNominal.inheritanceTypes?.compactMap {
        try? SwiftType($0.type, lookupContext: lookupContext)
      } ?? []
    self.parent = swiftNominal.parent
    self.swiftType = swiftNominal.asSwiftType
  }

  /// Init for creating a specialization
  private init(base: ExtractedNominalType, specializedTypeName: String, genericArguments: [String: String]) {
    self.swiftNominal = base.swiftNominal
    self.specializationBaseType = base

    let selfType = SwiftType.nominal(
      SwiftNominalType(
        parent: swiftNominal.parent?.asSwiftNominalType,
        nominalTypeDecl: SwiftNominalTypeDeclaration(
          name: specializedTypeName,
          sourceFilePath: swiftNominal.sourceFilePath,
          moduleName: swiftNominal.moduleName,
          parent: swiftNominal.parent,
          node: swiftNominal.syntax
        ),
        genericArguments: []
      )
    )
    self.initializers = base.initializers.map { $0.clone(for: selfType) }
    self.methods = base.methods.map { $0.clone(for: selfType) }
    self.variables = base.variables.map { $0.clone(for: selfType) }
    self.cases = base.cases.map { $0.clone(for: selfType) }
    self.inheritedTypes = base.inheritedTypes
    self.parent = base.parent

    self.specializedTypeName = specializedTypeName
    self.genericArguments = genericArguments
    self.swiftType = selfType
  }

  public let swiftType: SwiftType

  /// Structured output-facing type name — "FishBox" for specialized, "Box" for base
  public var effectiveOutputTypeName: SwiftQualifiedTypeName {
    if let specializedTypeName {
      return SwiftQualifiedTypeName(specializedTypeName)
    }
    return swiftNominal.qualifiedTypeName
  }

  /// The effective Swift-side type name used as a registration key in the
  /// analyzer's type table - "FishBox" for a specialization registered via
  /// `typealias FishBox = Box<Fish>`, the qualified base name (e.g. "Box")
  /// for a non-specialized type. Output-language-facing names live on the
  /// downstream code generator (e.g. JExtractSwiftLib's `effectiveJavaName`).
  public var effectiveTypeName: String {
    effectiveOutputTypeName.fullName
  }

  /// The Swift type for thunk generation — "Box<Fish>" for specialized, "Box" for base
  /// Computed from baseTypeName + genericArguments
  public var effectiveSwiftTypeName: String {
    guard !genericArguments.isEmpty else { return baseTypeName }
    let orderedArgs = genericParameterNames.compactMap { genericArguments[$0] }
    guard !orderedArgs.isEmpty else { return baseTypeName }
    return "\(baseTypeName)<\(orderedArgs.joined(separator: ", "))>"
  }

  public var qualifiedName: String {
    self.swiftNominal.qualifiedName
  }

  /// The attribute list on this type's declaration (e.g. `@resultBuilder`),
  /// for language targets that key behavior off attributes.
  /// Mirrors `ExtractedFunc.swiftDecl` being public for the function case.
  public var declAttributes: AttributeListSyntax {
    swiftNominal.syntax.attributes
  }

  /// The declaration-group syntax for this type (protocol/struct/class/enum/
  /// actor), for language targets that need to inspect members or clauses the
  /// neutral model doesn't surface (e.g. a protocol's primary associated types).
  public var declGroupSyntax: any DeclGroupSyntax & NamedDeclSyntax & WithAttributesSyntax & WithModifiersSyntax {
    swiftNominal.syntax
  }

  /// The output generic clause, e.g. "<Element>" for generic base types, "" for specialized or non-generic
  public var outputGenericClause: String {
    if isSpecialization {
      ""
    } else if genericParameterNames.isEmpty {
      ""
    } else {
      "<\(genericParameterNames.joined(separator: ", "))>"
    }
  }

  /// Create a specialized version of this generic type
  public func specialize(
    as specializedName: String,
    with substitutions: [String: String],
  ) throws -> ExtractedNominalType {
    guard !genericParameterNames.isEmpty else {
      throw SpecializationError(
        message: "Unable to specialize non-generic type '\(baseTypeName)' as '\(specializedName)'"
      )
    }
    let missingParams = genericParameterNames.filter { substitutions[$0] == nil }
    guard missingParams.isEmpty else {
      throw SpecializationError(
        message: "Missing type arguments for: \(missingParams) when specializing \(baseTypeName) as \(specializedName)"
      )
    }

    if swiftNominal.kind == .enum {
      throw SpecializationError(
        message: "Specialization for enums are not yet supported: '\(baseTypeName)' as '\(specializedName)'"
      )
    }

    return ExtractedNominalType(
      base: self,
      specializedTypeName: specializedName,
      genericArguments: substitutions,
    )
  }

  /// Checks if this type, or any of types it inherits from, conforms to the passed in protocol.
  public func conformsTo(_ protocolName: String, in extractedTypes: [SwiftTypeName: ExtractedNominalType]) -> Bool {
    var visited: Set<ObjectIdentifier> = []
    var queue: [ExtractedNominalType] = [self]
    while let current = queue.popLast() {
      for inherited in current.inheritedTypes {
        guard let name = inherited.asNominalTypeDeclaration?.name else { continue }
        if name == protocolName { return true }
        if let next = extractedTypes[name], visited.insert(ObjectIdentifier(next)).inserted {
          queue.append(next)
        }
      }
    }
    return false
  }
}

public struct SpecializationError: Error {
  public let message: String
}

public final class ExtractedEnumCase: ExtractedSwiftDecl, CustomStringConvertible {
  /// The case name
  public let name: String

  /// The enum parameters
  public let parameters: [SwiftEnumCaseParameter]

  public let swiftDecl: any DeclSyntaxProtocol

  public let enumType: SwiftNominalType

  /// A function that represents the Swift static "initializer" for cases
  public let caseFunction: ExtractedFunc

  public init(
    name: String,
    parameters: [SwiftEnumCaseParameter],
    swiftDecl: any DeclSyntaxProtocol,
    enumType: SwiftNominalType,
    caseFunction: ExtractedFunc,
  ) {
    self.name = name
    self.parameters = parameters
    self.swiftDecl = swiftDecl
    self.enumType = enumType
    self.caseFunction = caseFunction
  }

  public var description: String {
    """
    ExtractedEnumCase {
      name: \(name),
      parameters: \(parameters),
      swiftDecl: \(swiftDecl),
      enumType: \(enumType),
      caseFunction: \(caseFunction)
    }
    """
  }

  public func clone(for parent: SwiftType) -> ExtractedEnumCase {
    ExtractedEnumCase(
      name: name,
      parameters: parameters,
      swiftDecl: swiftDecl,
      enumType: enumType,
      caseFunction: caseFunction.clone(for: parent)
    )
  }
}

extension ExtractedEnumCase: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  public static func == (lhs: ExtractedEnumCase, rhs: ExtractedEnumCase) -> Bool {
    lhs === rhs
  }
}

public final class ExtractedFunc: ExtractedSwiftDecl, CustomStringConvertible {
  /// Swift module name (e.g. the target name where a type or function was declared)
  public let module: String

  /// The function name.
  /// e.g., "init" for an initializer or "foo" for "foo(a:b:)".
  public let name: String

  public let swiftDecl: any DeclSyntaxProtocol

  public let apiKind: SwiftAPIKind

  public let functionSignature: SwiftFunctionSignature

  public var signatureString: String {
    self.swiftDecl.signatureString
  }

  public var parentType: SwiftType? {
    functionSignature.selfParameter?.selfType
  }

  public var isStatic: Bool {
    if case .staticMethod = functionSignature.selfParameter {
      return true
    }
    return false
  }

  public var isInitializer: Bool {
    if case .initializer = functionSignature.selfParameter {
      return true
    }
    return false
  }

  /// If this function/method is member of a class/struct/protocol,
  /// this will contain that declaration's extracted name.
  public var hasParent: Bool { functionSignature.selfParameter != nil }

  /// A display name to use to refer to the Swift declaration with its
  /// enclosing type, if there is one.
  public var displayName: String {
    let prefix =
      switch self.apiKind {
      case .getter: "getter:"
      case .setter: "setter:"
      case .enumCase: "case:"
      case .function, .initializer: ""
      case .subscriptGetter: "subscriptGetter:"
      case .subscriptSetter: "subscriptSetter:"
      case .operator: "operator:"
      }

    let context =
      if let parentType {
        "\(parentType)."
      } else {
        ""
      }

    return prefix + context + self.name
  }

  public var isThrowing: Bool {
    self.functionSignature.effectSpecifiers.contains(.throws)
  }

  public var isAsync: Bool {
    self.functionSignature.isAsync
  }

  public init(
    module: String,
    swiftDecl: any DeclSyntaxProtocol,
    name: String,
    apiKind: SwiftAPIKind,
    functionSignature: SwiftFunctionSignature,
  ) {
    self.module = module
    self.name = name
    self.swiftDecl = swiftDecl
    self.apiKind = apiKind
    self.functionSignature = functionSignature
  }

  public var description: String {
    """
    ExtractedFunc {
      apiKind: \(apiKind)
      module: \(module)
      name: \(name)
      signature: \(self.swiftDecl.signatureString)
    }
    """
  }

  public func clone(for parent: SwiftType) -> ExtractedFunc {
    var functionSignature = functionSignature
    assert(functionSignature.selfParameter?.selfType != nil)
    functionSignature.selfParameter?.selfType = parent
    return ExtractedFunc(
      module: module,
      swiftDecl: swiftDecl,
      name: name,
      apiKind: apiKind,
      functionSignature: functionSignature
    )
  }
}

extension ExtractedFunc: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  public static func == (lhs: ExtractedFunc, rhs: ExtractedFunc) -> Bool {
    lhs === rhs
  }
}

extension ExtractedNominalType: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  public static func == (lhs: ExtractedNominalType, rhs: ExtractedNominalType) -> Bool {
    lhs === rhs
  }
}
