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

/// Any imported (Swift) declaration
protocol ImportedDecl: AnyObject {}

package enum SwiftAPIKind: Equatable {
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
package final class ImportedNominalType: ImportedDecl {
  let swiftNominal: SwiftNominalTypeDeclaration

  /// If this type is a specialization (FishTank), then this points at the Tank base type of the specialization.
  /// His allows simplified
  package let specializationBaseType: ImportedNominalType?

  // The short path from module root to the file in which this nominal was originally declared.
  // E.g. for `Sources/Example/My/Types.swift` it would be `My/Types.swift`.
  package var sourceFilePath: String {
    self.swiftNominal.sourceFilePath
  }

  // Backing storage for member collections
  private var _initializers: [ImportedFunc] = []
  private var _methods: [ImportedFunc] = []
  private var _variables: [ImportedFunc] = []
  private var _cases: [ImportedEnumCase] = []
  private var _inheritedTypes: [SwiftType]
  private var _parent: SwiftNominalTypeDeclaration?

  // Additional members from constrained extensions that only apply to this specialization
  package var constrainedInitializers: [ImportedFunc] = []
  package var constrainedMethods: [ImportedFunc] = []
  package var constrainedVariables: [ImportedFunc] = []

  package var initializers: [ImportedFunc] {
    get {
      if let specializationBaseType { specializationBaseType.initializers + constrainedInitializers } else { _initializers }
    }
    set {
      if let specializationBaseType {
        let baseSet = Set(specializationBaseType.initializers.map { ObjectIdentifier($0) })
        constrainedInitializers = newValue.filter { !baseSet.contains(ObjectIdentifier($0)) }
      } else {
        _initializers = newValue
      }
    }
  }
  package var methods: [ImportedFunc] {
    get {
      if let specializationBaseType { specializationBaseType.methods + constrainedMethods } else { _methods }
    }
    set {
      if let specializationBaseType {
        let baseSet = Set(specializationBaseType.methods.map { ObjectIdentifier($0) })
        constrainedMethods = newValue.filter { !baseSet.contains(ObjectIdentifier($0)) }
      } else {
        _methods = newValue
      }
    }
  }
  package var variables: [ImportedFunc] {
    get {
      if let specializationBaseType { specializationBaseType.variables + constrainedVariables } else { _variables }
    }
    set {
      if let specializationBaseType {
        let baseSet = Set(specializationBaseType.variables.map { ObjectIdentifier($0) })
        constrainedVariables = newValue.filter { !baseSet.contains(ObjectIdentifier($0)) }
      } else {
        _variables = newValue
      }
    }
  }
  package var cases: [ImportedEnumCase] {
    get {
      if let specializationBaseType { specializationBaseType.cases } else { _cases }
    }
    set {
      if let specializationBaseType { specializationBaseType.cases = newValue } else { _cases = newValue }
    }
  }
  var inheritedTypes: [SwiftType] {
    get {
      if let specializationBaseType { specializationBaseType.inheritedTypes } else { _inheritedTypes }
    }
    set {
      if let specializationBaseType { specializationBaseType.inheritedTypes = newValue } else { _inheritedTypes = newValue }
    }
  }
  package var parent: SwiftNominalTypeDeclaration? {
    get {
      if let specializationBaseType { specializationBaseType.parent } else { _parent }
    }
    set {
      if let specializationBaseType { specializationBaseType.parent = newValue } else { _parent = newValue }
    }
  }

  /// The Swift base type name, e.g. "Box" — always the unparameterized name
  package var baseTypeName: String { swiftNominal.qualifiedName }

  /// The specialized/Java-facing name, e.g. "FishBox" — nil for base types
  package private(set) var specializedTypeName: String?

  /// Whether this type is a specialization of a generic type
  package var isSpecialization: Bool { specializationBaseType != nil }

  /// Generic parameter names (e.g. ["Element"] for Box<Element>). Empty for non-generic types
  package var genericParameterNames: [String] {
    swiftNominal.genericParameters.map(\.name)
  }

  /// Maps generic parameter -> concrete type argument. Empty for unspecialized types
  /// e.g. {"Element": "Fish"} for FishBox
  package var genericArguments: [String: String] = [:]

  /// True when all generic parameters have corresponding arguments
  package var isFullySpecialized: Bool {
    !genericParameterNames.isEmpty && genericParameterNames.allSatisfy { genericArguments.keys.contains($0) }
  }

  init(swiftNominal: SwiftNominalTypeDeclaration, lookupContext: SwiftTypeLookupContext) throws {
    self.swiftNominal = swiftNominal
    self.specializationBaseType = nil
    self._inheritedTypes =
      swiftNominal.inheritanceTypes?.compactMap {
        try? SwiftType($0.type, lookupContext: lookupContext)
      } ?? []
    self._parent = swiftNominal.parent
  }

  /// Init for creating a specialization
  private init(base: ImportedNominalType, specializedTypeName: String, genericArguments: [String: String]) {
    self.swiftNominal = base.swiftNominal
    self.specializationBaseType = base
    self.specializedTypeName = specializedTypeName
    self.genericArguments = genericArguments
    self._inheritedTypes = []
  }

  var swiftType: SwiftType {
    .nominal(.init(nominalTypeDecl: swiftNominal))
  }

  /// Structured Java-facing type name — "FishBox" for specialized, "Box" for base
  package var effectiveJavaTypeName: SwiftQualifiedTypeName {
    if let specializedTypeName {
      return SwiftQualifiedTypeName(specializedTypeName)
    }
    return swiftNominal.qualifiedTypeName
  }

  /// The effective Java-facing name — "FishBox" for specialized, "Box" for base
  var effectiveJavaName: String {
    effectiveJavaTypeName.fullName
  }

  /// The simple Java class name (no qualification) for file naming purposes
  var effectiveJavaSimpleName: String {
    specializedTypeName ?? swiftNominal.name
  }

  /// The Swift type for thunk generation — "Box<Fish>" for specialized, "Box" for base
  /// Computed from baseTypeName + genericArguments
  var effectiveSwiftTypeName: String {
    guard !genericArguments.isEmpty else { return baseTypeName }
    let orderedArgs = genericParameterNames.compactMap { genericArguments[$0] }
    guard !orderedArgs.isEmpty else { return baseTypeName }
    return "\(baseTypeName)<\(orderedArgs.joined(separator: ", "))>"
  }

  var qualifiedName: String {
    self.swiftNominal.qualifiedName
  }

  /// The Java generic clause, e.g. "<Element>" for generic base types, "" for specialized or non-generic
  var javaGenericClause: String {
    if isSpecialization {
      ""
    } else if genericParameterNames.isEmpty {
      ""
    } else {
      "<\(genericParameterNames.joined(separator: ", "))>"
    }
  }

  /// Create a specialized version of this generic type
  package func specialize(
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
}

struct SpecializationError: Error {
  let message: String
}

public final class ImportedEnumCase: ImportedDecl, CustomStringConvertible {
  /// The case name
  public var name: String

  /// The enum parameters
  var parameters: [SwiftEnumCaseParameter]

  var swiftDecl: any DeclSyntaxProtocol

  var enumType: SwiftNominalType

  /// A function that represents the Swift static "initializer" for cases
  var caseFunction: ImportedFunc

  init(
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
}

extension ImportedEnumCase: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  public static func == (lhs: ImportedEnumCase, rhs: ImportedEnumCase) -> Bool {
    lhs === rhs
  }
}

public final class ImportedFunc: ImportedDecl, CustomStringConvertible {
  /// Swift module name (e.g. the target name where a type or function was declared)
  public var module: String

  /// The function name.
  /// e.g., "init" for an initializer or "foo" for "foo(a:b:)".
  public var name: String

  public var swiftDecl: any DeclSyntaxProtocol

  package var apiKind: SwiftAPIKind

  var functionSignature: SwiftFunctionSignature

  public var signatureString: String {
    self.swiftDecl.signatureString
  }

  var parentType: SwiftType? {
    functionSignature.selfParameter?.selfType
  }

  var isStatic: Bool {
    if case .staticMethod = functionSignature.selfParameter {
      return true
    }
    return false
  }

  var isInitializer: Bool {
    if case .initializer = functionSignature.selfParameter {
      return true
    }
    return false
  }

  /// If this function/method is member of a class/struct/protocol,
  /// this will contain that declaration's imported name.
  ///
  /// This is necessary when rendering accessor Java code we need the type that "self" is expecting to have.
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

  var isThrowing: Bool {
    self.functionSignature.effectSpecifiers.contains(.throws)
  }

  var isAsync: Bool {
    self.functionSignature.isAsync
  }

  init(
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
}

extension ImportedFunc: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
  public static func == (lhs: ImportedFunc, rhs: ImportedFunc) -> Bool {
    lhs === rhs
  }
}

extension ImportedFunc {
  var javaGetterName: String {
    let returnsBoolean = self.functionSignature.result.type.asNominalTypeDeclaration?.knownTypeKind == .bool

    if !returnsBoolean {
      return "get\(self.name.firstCharacterUppercased)"
    } else if !self.name.hasJavaBooleanNamingConvention {
      return "is\(self.name.firstCharacterUppercased)"
    } else {
      return self.name
    }
  }

  var javaSetterName: String {
    let isBooleanSetter = self.functionSignature.parameters.first?.type.asNominalTypeDeclaration?.knownTypeKind == .bool

    // If the variable is already named "isX", then we make
    // the setter "setX" to match beans spec.
    if isBooleanSetter && self.name.hasJavaBooleanNamingConvention {
      // Safe to force unwrap due to `hasJavaBooleanNamingConvention` check.
      let propertyName = self.name.split(separator: "is", maxSplits: 1).last!
      return "set\(propertyName)"
    } else {
      return "set\(self.name.firstCharacterUppercased)"
    }
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
