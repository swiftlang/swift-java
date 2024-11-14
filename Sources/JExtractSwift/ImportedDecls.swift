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

import Foundation
import JavaTypes
import SwiftSyntax

/// Any imported (Swift) declaration
protocol ImportedDecl {

}

public typealias JavaPackage = String

/// Describes a Swift nominal type (e.g., a class, struct, enum) that has been
/// imported and is being translated into Java.
public struct ImportedNominalType: ImportedDecl {
  public let swiftTypeName: String
  public let javaType: JavaType
  public var kind: NominalTypeKind

  public var initializers: [ImportedFunc] = []
  public var methods: [ImportedFunc] = []
  public var variables: [ImportedVariable] = []

  public init(swiftTypeName: String, javaType: JavaType, kind: NominalTypeKind) {
    self.swiftTypeName = swiftTypeName
    self.javaType = javaType
    self.kind = kind
  }

  var translatedType: TranslatedType {
    TranslatedType(
      cCompatibleConvention: .direct,
      originalSwiftType: "\(raw: swiftTypeName)",
      cCompatibleSwiftType: "UnsafeRawPointer",
      cCompatibleJavaMemoryLayout: .heapObject,
      javaType: javaType
    )
  }

  /// The Java class name without the package.
  public var javaClassName: String {
    switch javaType {
    case .class(package: _, let name): name
    default: javaType.description
    }
  }
}

public enum NominalTypeKind {
  case `actor`
  case `class`
  case `enum`
  case `struct`
}

public struct ImportedParam {
  let syntax: FunctionParameterSyntax

  var firstName: String? {
    let text = syntax.firstName.trimmed.text
    guard text != "_" else {
      return nil
    }

    return text
  }

  var secondName: String? {
    let text = syntax.secondName?.trimmed.text
    guard text != "_" else {
      return nil
    }

    return text
  }

  var effectiveName: String? {
    firstName ?? secondName
  }

  // The Swift type as-is from the swift interface
  var swiftType: String {
    syntax.type.trimmed.description
  }

  // The mapped-to Java type of the above Java type, collections and optionals may be replaced with Java ones etc.
  var type: TranslatedType
}

extension ImportedParam {
  func renderParameterForwarding() -> String? {
    if type.javaType.isPrimitive {
      effectiveName
    } else if type.javaType.isSwiftClosure {
      // use the name of the upcall handle we'll have emitted by now
      "\(effectiveName!)$"
    } else {
      "\(effectiveName!).$memorySegment()"
    }
  }
}

// TODO: this is used in different contexts and needs a cleanup
//       Perhaps this is "which parameter passing style"?
public enum SelfParameterVariant {
  // ==== Java forwarding patterns

  /// Make a method that accepts the raw memory pointer as a MemorySegment
  case memorySegment
  /// Make a method that accepts the the Java wrapper class of the type
  case wrapper
  /// Raw SWIFT_POINTER
  case pointer

  // ==== Swift forwarding patterns

  case swiftThunkSelf
}

public struct ImportedFunc: ImportedDecl, CustomStringConvertible {

  /// Swift module name (e.g. the target name where a type or function was declared)
  public var module: String

  /// If this function/method is member of a class/struct/protocol,
  /// this will contain that declaration's imported name.
  ///
  /// This is necessary when rendering accessor Java code we need the type that "self" is expecting to have.
  public var parent: TranslatedType?
  public var hasParent: Bool { parent != nil }

  /// This is a full name such as init(cap:name:).
  public var identifier: String

  /// This is the base identifier for the function, e.g., "init" for an
  /// initializer or "f" for "f(a:b:)".
  public var baseIdentifier: String {
    guard let idx = identifier.firstIndex(of: "(") else {
      return identifier
    }
    return String(identifier[..<idx])
  }

  /// A display name to use to refer to the Swift declaration with its
  /// enclosing type, if there is one.
  public var displayName: String {
    if let parent {
      return "\(parent.swiftTypeName).\(identifier)"
    }

    return identifier
  }

  public var returnType: TranslatedType
  public var parameters: [ImportedParam]

  public func effectiveParameters(paramPassingStyle: SelfParameterVariant?) -> [ImportedParam] {
    if let parent {
      var params = parameters

      // Add `self: Self` for method calls on a member
      //
      // allocating initializer takes a Self.Type instead, but it's also a pointer
      switch paramPassingStyle {
      case nil, .wrapper:
        break

      case .pointer:
        let selfParam: FunctionParameterSyntax = "self$: $swift_pointer"
        params.append(
          ImportedParam(syntax: selfParam, type: parent)
        )

      case .memorySegment:
        let selfParam: FunctionParameterSyntax = "self$: $java_lang_foreign_MemorySegment"
        var parentForSelf = parent
        parentForSelf.javaType = .javaForeignMemorySegment
        params.append(
          ImportedParam(syntax: selfParam, type: parentForSelf)
        )

      case .swiftThunkSelf:
        break
      }

      // TODO: add any metadata for generics and other things we may need to add here

      return params
    } else {
      return self.parameters
    }
  }

  public var swiftDecl: any DeclSyntaxProtocol

  public var syntax: String? {
    "\(self.swiftDecl)"
  }

  public var isInit: Bool = false

  public init(
    module: String,
    decl: any DeclSyntaxProtocol,
    parent: TranslatedType?,
    identifier: String,
    returnType: TranslatedType,
    parameters: [ImportedParam]
  ) {
    self.swiftDecl = decl
    self.module = module
    self.parent = parent
    self.identifier = identifier
    self.returnType = returnType
    self.parameters = parameters
  }

  public var description: String {
    """
    ImportedFunc {
      identifier: \(identifier)
      returnType: \(returnType)
      parameters: \(parameters)

    Swift mangled name:
      Imported from:
      \(syntax?.description ?? "<no swift source>")
    }
    """
  }
}

extension ImportedFunc: Hashable {
  public func hash(into hasher: inout Swift.Hasher) {
    self.swiftDecl.id.hash(into: &hasher)
  }

  public static func ==(lhs: ImportedFunc, rhs: ImportedFunc) -> Swift.Bool {
    lhs.parent?.originalSwiftType.id == rhs.parent?.originalSwiftType.id &&
    lhs.swiftDecl.id == rhs.swiftDecl.id
  }
}

public enum VariableAccessorKind {
  case get
  case set
}

public struct ImportedVariable: ImportedDecl, CustomStringConvertible {

  public var module: String

  /// If this function/method is member of a class/struct/protocol,
  /// this will contain that declaration's imported name.
  ///
  /// This is necessary when rendering accessor Java code we need the type that "self" is expecting to have.
  public var parentName: TranslatedType?
  public var hasParent: Bool { parentName != nil }

  /// This is a full name such as "counter".
  public var identifier: String

  /// Which accessors are we able to expose.
  ///
  /// Usually this will be all the accessors the variable declares,
  /// however if the getter is async or throwing we may not be able to import it
  /// (yet), and therefore would skip it from the supported set.
  public var supportedAccessorKinds: [VariableAccessorKind] = [.get, .set]

  /// This is the base identifier for the function, e.g., "init" for an
  /// initializer or "f" for "f(a:b:)".
  public var baseIdentifier: String {
    guard let idx = identifier.firstIndex(of: "(") else {
      return identifier
    }
    return String(identifier[..<idx])
  }

  /// A display name to use to refer to the Swift declaration with its
  /// enclosing type, if there is one.
  public var displayName: String {
    if let parentName {
      return "\(parentName.swiftTypeName).\(identifier)"
    }

    return identifier
  }

  public var returnType: TranslatedType

  /// Synthetic signature of an accessor function of the given kind of this property
  public func accessorFunc(kind: VariableAccessorKind) -> ImportedFunc? {
    guard self.supportedAccessorKinds.contains(kind) else {
      return nil
    }

    switch kind {
    case .set:
      let newValueParam: FunctionParameterSyntax =
        "_ newValue: \(self.returnType.cCompatibleSwiftType)"
      let funcDecl = ImportedFunc(
        module: self.module,
        decl: self.syntax!,
        parent: self.parentName,
        identifier: self.identifier,
        returnType: TranslatedType.void,
        parameters: [.init(syntax: newValueParam, type: self.returnType)])
      return funcDecl

    case .get:
      let funcDecl = ImportedFunc(
        module: self.module,
        decl: self.syntax!,
        parent: self.parentName,
        identifier: self.identifier,
        returnType: self.returnType,
        parameters: [])
      return funcDecl
    }
  }

  public func effectiveAccessorParameters(
    _ kind: VariableAccessorKind, paramPassingStyle: SelfParameterVariant?
  ) -> [ImportedParam] {
    var params: [ImportedParam] = []

    if kind == .set {
      let newValueParam: FunctionParameterSyntax =
        "_ newValue: \(raw: self.returnType.swiftTypeName)"
      params.append(
        ImportedParam(
          syntax: newValueParam,
          type: self.returnType)
      )
    }

    if let parentName {
      // Add `self: Self` for method calls on a member
      //
      // allocating initializer takes a Self.Type instead, but it's also a pointer
      switch paramPassingStyle {
      case .pointer:
        let selfParam: FunctionParameterSyntax = "self$: $swift_pointer"
        params.append(
          ImportedParam(
            syntax: selfParam,
            type: parentName
          )
        )

      case .memorySegment:
        let selfParam: FunctionParameterSyntax = "self$: $java_lang_foreign_MemorySegment"
        var parentForSelf = parentName
        parentForSelf.javaType = .javaForeignMemorySegment
        params.append(
          ImportedParam(
            syntax: selfParam,
            type: parentForSelf
          )
        )

      case nil,
           .wrapper,
           .swiftThunkSelf:
        break
      }
    }

    return params
  }

  public var swiftMangledName: String = ""

  public var syntax: VariableDeclSyntax? = nil

  public init(
    module: String,
    parentName: TranslatedType?,
    identifier: String,
    returnType: TranslatedType
  ) {
    self.module = module
    self.parentName = parentName
    self.identifier = identifier
    self.returnType = returnType
  }

  public var description: String {
    """
    ImportedFunc {
      mangledName: \(swiftMangledName)
      identifier: \(identifier)
      returnType: \(returnType)

    Swift mangled name:
      Imported from:
      \(syntax?.description ?? "<no swift source>")
    }
    """
  }
}
