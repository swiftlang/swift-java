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

package enum SwiftAPIKind {
  case function
  case initializer
  case getter
  case setter
  case enumCase
}

/// Describes a Swift nominal type (e.g., a class, struct, enum) that has been
/// imported and is being translated into Java.
package class ImportedNominalType: ImportedDecl {
  let swiftNominal: SwiftNominalTypeDeclaration

  package var initializers: [ImportedFunc] = []
  package var methods: [ImportedFunc] = []
  package var variables: [ImportedFunc] = []
  package var cases: [ImportedEnumCase] = []
  var inheritedTypes: [SwiftType]

  init(swiftNominal: SwiftNominalTypeDeclaration, lookupContext: SwiftTypeLookupContext) throws {
    self.swiftNominal = swiftNominal
    self.inheritedTypes = swiftNominal.inheritanceTypes?.compactMap {
      try? SwiftType($0.type, lookupContext: lookupContext)
    } ?? []
  }

  var swiftType: SwiftType {
    return .nominal(.init(nominalTypeDecl: swiftNominal))
  }

  var qualifiedName: String {
    self.swiftNominal.qualifiedName
  }
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
    caseFunction: ImportedFunc
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
    return lhs === rhs
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
    guard let selfParameter = functionSignature.selfParameter else {
      return nil
    }
    switch selfParameter {
    case .instance(let parameter):
      return parameter.type
    case .staticMethod(let type):
      return type
    case .initializer(let type):
      return type
    }
  }

  /// If this function type uses types that require any additional `import` statements,
  /// these would be exported here.
  var additionalJavaImports: Set<String> {
    var imports: Set<String> = []
//    imports += self.functionSignature.parameters.flatMap { $0.additionalJavaImports }
//    imports += self.functionSignature.result.additionalJavaImports
    return imports
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
    let prefix = switch self.apiKind {
    case .getter: "getter:"
    case .setter: "setter:"
    case .enumCase: "case:"
    case .function, .initializer: ""
    }

    let context = if let parentType {
      "\(parentType)."
    } else {
      ""
    }

    return prefix + context + self.name
  }

  var isThrowing: Bool {
    self.functionSignature.effectSpecifiers.contains(.throws)
  }

  init(
    module: String,
    swiftDecl: any DeclSyntaxProtocol,
    name: String,
    apiKind: SwiftAPIKind,
    functionSignature: SwiftFunctionSignature
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
    return lhs === rhs
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
