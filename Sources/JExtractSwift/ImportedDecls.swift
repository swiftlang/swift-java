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

protocol ImportedDecl {

}

public typealias JavaPackage = String

/// Describes a Swift nominal type (e.g., a class, struct, enum) that has been
/// imported and is being translated into Java.
public struct ImportedNominalType: ImportedDecl {
  public let swiftTypeName: String
  public let javaType: JavaType
  public var swiftMangledName: String?
  public var kind: NominalTypeKind

  public var initializers: [ImportedFunc] = []
  public var methods: [ImportedFunc] = []

  public init(swiftTypeName: String, javaType: JavaType, swiftMangledName: String? = nil, kind: NominalTypeKind) {
    self.swiftTypeName = swiftTypeName
    self.javaType = javaType
    self.swiftMangledName = swiftMangledName
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
    case .class(package: _, name: let name): name
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
  let param: FunctionParameterSyntax

  var firstName: String? {
    let text = param.firstName.trimmed.text
    guard text != "_" else {
      return nil
    }

    return text
  }

  var secondName: String? {
    let text = param.secondName?.trimmed.text
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
    param.type.trimmed.description
  }

  // The mapped-to Java type of the above Java type, collections and optionals may be replaced with Java ones etc.
  var type: TranslatedType
}

extension ImportedParam {
  func renderParameterForwarding() -> String? {
    if type.javaType.isPrimitive {
      return effectiveName
    }

    return "\(effectiveName!).$memorySegment()"
  }
}

// TODO: this is used in different contexts and needs a cleanup
public enum SelfParameterVariant {
  /// Make a method that accepts the raw memory pointer as a MemorySegment
  case memorySegment
  /// Make a method that accepts the the Java wrapper class of the type
  case wrapper
  /// Raw SWIFT_POINTER
  case pointer
}

public struct ImportedFunc: ImportedDecl, CustomStringConvertible {
  /// If this function/method is member of a class/struct/protocol,
  /// this will contain that declaration's imported name.
  ///
  /// This is necessary when rendering accessor Java code we need the type that "self" is expecting to have.
  public var parentName: TranslatedType?
  public var hasParent: Bool { parentName != nil }

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
    if let parentName {
      return "\(parentName.swiftTypeName).\(identifier)"
    }

    return identifier
  }

  public var returnType: TranslatedType
  public var parameters: [ImportedParam]

  public func effectiveParameters(selfVariant: SelfParameterVariant?) -> [ImportedParam] {
    if let parentName {
      var params = parameters

      // Add `self: Self` for method calls on a member
      //
      // allocating initializer takes a Self.Type instead, but it's also a pointer
      switch selfVariant {
      case nil, .wrapper:
        break

      case .pointer:
        let selfParam: FunctionParameterSyntax = "self$: $swift_pointer"
        params.append(
          ImportedParam(
            param: selfParam,
            type: parentName
          )
        )

      case .memorySegment:
        let selfParam: FunctionParameterSyntax = "self$: $java_lang_foreign_MemorySegment"
        var parentForSelf = parentName
        parentForSelf.javaType = .javaForeignMemorySegment
        params.append(
          ImportedParam(
            param: selfParam,
            type: parentForSelf
          )
        )
      }

      // TODO: add any metadata for generics and other things we may need to add here

      return params
    } else {
      return self.parameters
    }
  }

  public var swiftMangledName: String = ""

  public var swiftDeclRaw: String? = nil

  public var isInit: Bool = false

  public init(
    parentName: TranslatedType?,
    identifier: String,
    returnType: TranslatedType,
    parameters: [ImportedParam]
  ) {
    self.parentName = parentName
    self.identifier = identifier
    self.returnType = returnType
    self.parameters = parameters
  }

  public var description: String {
    """
    ImportedFunc {
      mangledName: \(swiftMangledName)
      identifier: \(identifier)
      returnType: \(returnType)
      parameters: \(parameters)

    Swift mangled name:
      Imported from:
      \(swiftDeclRaw ?? "<no swift source>")
    }
    """
  }
}
