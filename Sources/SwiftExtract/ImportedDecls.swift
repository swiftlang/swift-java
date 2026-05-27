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
}

/// Describes a Swift nominal type (e.g., a class, struct, enum) that has been
/// imported and is being translated into Java.
///
/// When `base` is non-nil, this is a specialization of a generic type
/// (e.g. `FishBox` specializing `Box<Element>` with `Element` = `Fish`).
/// The specialization delegates its member collections to the base type
/// so that extensions discovered later are visible through all specializations.
public final class ImportedNominalType: ExtractedSwiftDecl {
  public let swiftNominal: SwiftNominalTypeDeclaration

  /// If this type is a specialization (FishTank), it points at the Tank base type of the specialization
  public let specializationBaseType: ImportedNominalType?

  // The short path from module root to the file in which this nominal was originally declared.
  // E.g. for `Sources/Example/My/Types.swift` it would be `My/Types.swift`.
  public var sourceFilePath: String {
    self.swiftNominal.sourceFilePath
  }

  // Backing storage for member collections
  public var initializers: [ImportedFunc] = []
  public var methods: [ImportedFunc] = []
  public var variables: [ImportedFunc] = []
  public var cases: [ImportedEnumCase] = []
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
  private init(base: ImportedNominalType, specializedTypeName: String, genericArguments: [String: String]) {
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

  /// The effective output-facing name — "FishBox" for specialized, "Box" for base
  public var effectiveOutputName: String {
    effectiveOutputTypeName.fullName
  }

  /// The simple output-facing class name (no qualification) for file naming purposes
  public var effectiveOutputSimpleName: String {
    specializedTypeName ?? swiftNominal.name
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
  ) throws -> ImportedNominalType {
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
    return ImportedNominalType(
      base: self,
      specializedTypeName: specializedName,
      genericArguments: substitutions,
    )
  }

  /// Checks if this type, or any of types it inherits from, conforms to the passed in protocol.
  public func conformsTo(_ protocolName: String, in importedTypes: [String: ImportedNominalType]) -> Bool {
    var visited: Set<ObjectIdentifier> = []
    var queue: [ImportedNominalType] = [self]
    while let current = queue.popLast() {
      for inherited in current.inheritedTypes {
        guard let name = inherited.asNominalTypeDeclaration?.name else { continue }
        if name == protocolName { return true }
        if let next = importedTypes[name], visited.insert(ObjectIdentifier(next)).inserted {
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

public final class ImportedEnumCase: ExtractedSwiftDecl, CustomStringConvertible {
  /// The case name
  public let name: String

  /// The enum parameters
  public let parameters: [SwiftEnumCaseParameter]

  public let swiftDecl: any DeclSyntaxProtocol

  public let enumType: SwiftNominalType

  /// A function that represents the Swift static "initializer" for cases
  public let caseFunction: ImportedFunc

  public init(
    name: String,
    parameters: [SwiftEnumCaseParameter],
    swiftDecl: any DeclSyntaxProtocol,
    enumType: SwiftNominalType,
    caseFunction: ImportedFunc,
  ) {
    self.name = name
    self.parameters = parameters
    self.swiftDecl = swiftDecl
    self.enumType = enumType
    self.caseFunction = caseFunction
  }

  public var description: String {
    """
    ImportedEnumCase {
      name: \(name),
      parameters: \(parameters),
      swiftDecl: \(swiftDecl),
      enumType: \(enumType),
      caseFunction: \(caseFunction)
    }
    """
  }

  public func clone(for parent: SwiftType) -> ImportedEnumCase {
    ImportedEnumCase(
      name: name,
      parameters: parameters,
      swiftDecl: swiftDecl,
      enumType: enumType,
      caseFunction: caseFunction.clone(for: parent)
    )
  }
}

extension ImportedEnumCase: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  public static func == (lhs: ImportedEnumCase, rhs: ImportedEnumCase) -> Bool {
    lhs === rhs
  }
}

public final class ImportedFunc: ExtractedSwiftDecl, CustomStringConvertible {
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
  /// this will contain that declaration's imported name.
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
    ImportedFunc {
      apiKind: \(apiKind)
      module: \(module)
      name: \(name)
      signature: \(self.swiftDecl.signatureString)
    }
    """
  }

  public func clone(for parent: SwiftType) -> ImportedFunc {
    var functionSignature = functionSignature
    assert(functionSignature.selfParameter?.selfType != nil)
    functionSignature.selfParameter?.selfType = parent
    return ImportedFunc(
      module: module,
      swiftDecl: swiftDecl,
      name: name,
      apiKind: apiKind,
      functionSignature: functionSignature
    )
  }
}

extension ImportedFunc: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  public static func == (lhs: ImportedFunc, rhs: ImportedFunc) -> Bool {
    lhs === rhs
  }
}

extension ImportedNominalType: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  public static func == (lhs: ImportedNominalType, rhs: ImportedNominalType) -> Bool {
    lhs === rhs
  }
}
