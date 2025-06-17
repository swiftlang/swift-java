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

enum SwiftStandardLibraryTypeKind: String, Hashable, CaseIterable {
  case bool = "Bool"
  case int = "Int"
  case uint = "UInt"
  case int8 = "Int8"
  case uint8 = "UInt8"
  case int16 = "Int16"
  case uint16 = "UInt16"
  case int32 = "Int32"
  case uint32 = "UInt32"
  case int64 = "Int64"
  case uint64 = "UInt64"
  case float = "Float"
  case double = "Double"
  case unsafeRawPointer = "UnsafeRawPointer"
  case unsafeMutableRawPointer = "UnsafeMutableRawPointer"
  case unsafeRawBufferPointer = "UnsafeRawBufferPointer"
  case unsafeMutableRawBufferPointer = "UnsafeMutableRawBufferPointer"
  case unsafePointer = "UnsafePointer"
  case unsafeMutablePointer = "UnsafeMutablePointer"
  case unsafeBufferPointer = "UnsafeBufferPointer"
  case unsafeMutableBufferPointer = "UnsafeMutableBufferPointer"
  case string = "String"
  case void = "Void"

  var typeName: String { rawValue }

  init?(typeNameInSwiftModule: String) {
    self.init(rawValue: typeNameInSwiftModule)
  }

  /// Whether this declaration is generic.
  var isGeneric: Bool {
    switch self {
    case .bool, .double, .float, .int, .int8, .int16, .int32, .int64,
        .uint, .uint8, .uint16, .uint32, .uint64, .unsafeRawPointer,
        .unsafeMutableRawPointer, .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer,
        .string, .void:
      false

    case .unsafePointer, .unsafeMutablePointer, .unsafeBufferPointer,
        .unsafeMutableBufferPointer:
      true
    }
  }

  var isPointer: Bool {
    switch self {
    case .unsafePointer, .unsafeMutablePointer, .unsafeRawPointer, .unsafeMutableRawPointer:
      return true
    default:
      return false
    }
  }
}

/// Captures many types from the Swift standard library in their most basic
/// forms, so that the translator can reason about them in source code.
public struct SwiftStandardLibraryTypeDecls {
  // Swift.UnsafePointer<Element>
  let unsafePointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeMutablePointer<Element>
  let unsafeMutablePointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeBufferPointer<Element>
  let unsafeBufferPointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeMutableBufferPointer<Element>
  let unsafeMutableBufferPointerDecl: SwiftNominalTypeDeclaration

  /// Mapping from known standard library types to their nominal type declaration.
  let knownTypeToNominal: [SwiftStandardLibraryTypeKind: SwiftNominalTypeDeclaration]

  /// Mapping from nominal type declarations to known types.
  let nominalTypeDeclToKnownType: [SwiftNominalTypeDeclaration: SwiftStandardLibraryTypeKind]

  private static func recordKnownType(
    _ type: SwiftStandardLibraryTypeKind,
    _ syntax: NominalTypeDeclSyntaxNode,
    knownTypeToNominal: inout [SwiftStandardLibraryTypeKind: SwiftNominalTypeDeclaration],
    nominalTypeDeclToKnownType: inout [SwiftNominalTypeDeclaration: SwiftStandardLibraryTypeKind],
    parsedModule: inout SwiftParsedModuleSymbolTable
  ) {
    let nominalDecl = parsedModule.addNominalTypeDeclaration(syntax, parent: nil)
    knownTypeToNominal[type] = nominalDecl
    nominalTypeDeclToKnownType[nominalDecl] = type
  }

  private static func recordKnownNonGenericStruct(
    _ type: SwiftStandardLibraryTypeKind,
    knownTypeToNominal: inout [SwiftStandardLibraryTypeKind: SwiftNominalTypeDeclaration],
    nominalTypeDeclToKnownType: inout [SwiftNominalTypeDeclaration: SwiftStandardLibraryTypeKind],
    parsedModule: inout SwiftParsedModuleSymbolTable
  ) {
    recordKnownType(
      type,
      StructDeclSyntax(
        name: .identifier(type.typeName),
        memberBlock: .init(members: [])
      ),
      knownTypeToNominal: &knownTypeToNominal,
      nominalTypeDeclToKnownType: &nominalTypeDeclToKnownType,
      parsedModule: &parsedModule
    )
  }

  init(into parsedModule: inout SwiftParsedModuleSymbolTable) {
    // Pointer types
    self.unsafePointerDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("UnsafePointer"),
        genericParameterClause: .init(
          parameters: [GenericParameterSyntax(name: .identifier("Element"))]
        ),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )

    self.unsafeMutablePointerDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("UnsafeMutablePointer"),
        genericParameterClause: .init(
          parameters: [GenericParameterSyntax(name: .identifier("Element"))]
        ),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )

    self.unsafeBufferPointerDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("UnsafeBufferPointer"),
        genericParameterClause: .init(
          parameters: [GenericParameterSyntax(name: .identifier("Element"))]
        ),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )

    self.unsafeMutableBufferPointerDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("UnsafeMutableBufferPointer"),
        genericParameterClause: .init(
          parameters: [GenericParameterSyntax(name: .identifier("Element"))]
        ),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )

    var knownTypeToNominal: [SwiftStandardLibraryTypeKind: SwiftNominalTypeDeclaration] = [:]
    var nominalTypeDeclToKnownType: [SwiftNominalTypeDeclaration: SwiftStandardLibraryTypeKind] = [:]

    // Handle all of the non-generic types at once.
    for knownType in SwiftStandardLibraryTypeKind.allCases {
      guard !knownType.isGeneric else {
        continue
      }

      Self.recordKnownNonGenericStruct(
        knownType,
        knownTypeToNominal: &knownTypeToNominal,
        nominalTypeDeclToKnownType: &nominalTypeDeclToKnownType,
        parsedModule: &parsedModule
      )
    }

    self.knownTypeToNominal = knownTypeToNominal
    self.nominalTypeDeclToKnownType = nominalTypeDeclToKnownType
  }

  subscript(knownType: SwiftStandardLibraryTypeKind) -> SwiftNominalTypeDeclaration {
    knownTypeToNominal[knownType]!
  }

  subscript(nominalType: SwiftNominalTypeDeclaration) -> SwiftStandardLibraryTypeKind? {
    nominalTypeDeclToKnownType[nominalType]
  }
}
