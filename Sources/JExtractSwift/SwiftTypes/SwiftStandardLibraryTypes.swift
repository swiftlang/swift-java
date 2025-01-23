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

/// Captures many types from the Swift standard library in their most basic
/// forms, so that the translator can reason about them in source code.
struct SwiftStandardLibraryTypes {
  /// Swift.UnsafeRawPointer
  var unsafeRawPointerDecl: SwiftNominalTypeDeclaration

  /// Swift.UnsafeMutableRawPointer
  var unsafeMutableRawPointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafePointer<Element>
  var unsafePointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeMutablePointer<Element>
  var unsafeMutablePointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeBufferPointer<Element>
  var unsafeBufferPointerDecl: SwiftNominalTypeDeclaration

  // Swift.UnsafeMutableBufferPointer<Element>
  var unsafeMutableBufferPointerDecl: SwiftNominalTypeDeclaration

  /// Swift.Bool
  var boolDecl: SwiftNominalTypeDeclaration

  /// Swift.Int8
  var int8Decl: SwiftNominalTypeDeclaration

  /// Swift.Int16
  var int16Decl: SwiftNominalTypeDeclaration

  /// Swift.UInt16
  var uint16Decl: SwiftNominalTypeDeclaration

  /// Swift.Int32
  var int32Decl: SwiftNominalTypeDeclaration

  /// Swift.Int64
  var int64Decl: SwiftNominalTypeDeclaration

  /// Swift.Int
  var intDecl: SwiftNominalTypeDeclaration

  /// Swift.Float
  var floatDecl: SwiftNominalTypeDeclaration

  /// Swift.Double
  var doubleDecl: SwiftNominalTypeDeclaration

  /// Swift.String
  var stringDecl: SwiftNominalTypeDeclaration

  init(into parsedModule: inout SwiftParsedModuleSymbolTable) {
    // Pointer types
    self.unsafeRawPointerDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("UnsafeRawPointer"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )

    self.unsafeMutableRawPointerDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("UnsafeMutableRawPointer"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )

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

    self.boolDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Bool"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.intDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Int"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.int8Decl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Int8"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.int16Decl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Int16"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.uint16Decl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("UInt16"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.int32Decl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Int32"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.int64Decl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Int64"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.floatDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Float"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.doubleDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Double"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.intDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("Int"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
    self.stringDecl = parsedModule.addNominalTypeDeclaration(
      StructDeclSyntax(
        name: .identifier("String"),
        memberBlock: .init(members: [])
      ),
      parent: nil
    )
  }
}
