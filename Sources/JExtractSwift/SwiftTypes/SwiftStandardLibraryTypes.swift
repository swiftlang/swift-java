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

enum KnownStandardLibraryType: Int, Hashable, CaseIterable {
  case bool = 0
  case int
  case uint
  case int8
  case uint8
  case int16
  case uint16
  case int32
  case uint32
  case int64
  case uint64
  case float
  case double
  case unsafeRawPointer
  case unsafeMutableRawPointer

  var typeName: String {
    switch self {
      case .bool: return "Bool"
      case .int: return "Int"
      case .uint: return "UInt"
      case .int8: return "Int8"
      case .uint8: return "UInt8"
      case .int16: return "Int16"
      case .uint16: return "UInt16"
      case .int32: return "Int32"
      case .uint32: return "UInt32"
      case .int64: return "Int64"
      case .uint64: return "UInt64"
      case .float: return "Float"
      case .double: return "Double"
      case .unsafeRawPointer: return "UnsafeRawPointer"
      case .unsafeMutableRawPointer: return "UnsafeMutableRawPointer"
    }
  }

  var isGeneric: Bool {
    false
  }
}

/// Captures many types from the Swift standard library in their most basic
/// forms, so that the translator can reason about them in source code.
struct SwiftStandardLibraryTypes {
  // Swift.UnsafePointer<Element>
  let unsafePointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeMutablePointer<Element>
  let unsafeMutablePointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeBufferPointer<Element>
  let unsafeBufferPointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeMutableBufferPointer<Element>
  let unsafeMutableBufferPointerDecl: SwiftNominalTypeDeclaration

  /// Mapping from known standard library types to their nominal type declaration.
  let knownTypeToNominal: [KnownStandardLibraryType: SwiftNominalTypeDeclaration]

  /// Mapping from nominal type declarations to known types.
  let nominalTypeDeclToKnownType: [SwiftNominalTypeDeclaration: KnownStandardLibraryType]

  private static func recordKnownType(
    _ type: KnownStandardLibraryType,
    _ syntax: NominalTypeDeclSyntaxNode,
    knownTypeToNominal: inout [KnownStandardLibraryType: SwiftNominalTypeDeclaration],
    nominalTypeDeclToKnownType: inout [SwiftNominalTypeDeclaration: KnownStandardLibraryType],
    parsedModule: inout SwiftParsedModuleSymbolTable
  ) {
    let nominalDecl = parsedModule.addNominalTypeDeclaration(syntax, parent: nil)
    knownTypeToNominal[type] = nominalDecl
    nominalTypeDeclToKnownType[nominalDecl] = type
  }

  private static func recordKnownNonGenericStruct(
    _ type: KnownStandardLibraryType,
    knownTypeToNominal: inout [KnownStandardLibraryType: SwiftNominalTypeDeclaration],
    nominalTypeDeclToKnownType: inout [SwiftNominalTypeDeclaration: KnownStandardLibraryType],
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

    var knownTypeToNominal: [KnownStandardLibraryType: SwiftNominalTypeDeclaration] = [:]
    var nominalTypeDeclToKnownType: [SwiftNominalTypeDeclaration: KnownStandardLibraryType] = [:]

    // Handle all of the non-generic types at once.
    for knownType in KnownStandardLibraryType.allCases {
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

  subscript(knownType: KnownStandardLibraryType) -> SwiftNominalTypeDeclaration {
    knownTypeToNominal[knownType]!
  }

  subscript(nominalType: SwiftNominalTypeDeclaration) -> KnownStandardLibraryType? {
    nominalTypeDeclToKnownType[nominalType]
  }
}
