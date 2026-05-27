//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftExtract
import Testing

@Suite("SwiftKnownModule and SwiftKnownTypes")
struct SwiftKnownModuleSuite {

  // ==== -----------------------------------------------------------------------
  // MARK: Built-in Swift module catalog

  @Test(arguments: [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Float", "Double",
    "Bool", "String",
    "Array", "Dictionary", "Set", "Optional",
  ])
  func swiftModuleContains(_ typeName: String) throws {
    let table = SwiftKnownModule.swift.symbolTable
    let decl = try #require(table.lookupTopLevelNominalType(typeName))
    #expect(decl.name == typeName)
    #expect(decl.moduleName == "Swift")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: SwiftKnownTypes accessor

  @Test func knownTypesExposeNominalSwiftStdlibTypes() throws {
    let symbolTable = makeSymbolTable(sources: ["public struct X {}"])
    let known = SwiftKnownTypes(symbolTable: symbolTable)

    // Each accessor must yield a nominal type whose decl is the corresponding
    // Swift stdlib type.
    let int8Decl = try #require(known.int8.asNominalTypeDeclaration)
    #expect(int8Decl.knownTypeKind == .int8)

    let uint8Decl = try #require(known.uint8.asNominalTypeDeclaration)
    #expect(uint8Decl.knownTypeKind == .uint8)

    let stringDecl = try #require(known.string.asNominalTypeDeclaration)
    #expect(stringDecl.knownTypeKind == .string)

    let boolDecl = try #require(known.bool.asNominalTypeDeclaration)
    #expect(boolDecl.knownTypeKind == .bool)

    let doubleDecl = try #require(known.double.asNominalTypeDeclaration)
    #expect(doubleDecl.knownTypeKind == .double)
  }
}
