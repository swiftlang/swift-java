//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(Testing) import JExtractSwift
import SwiftSyntax
import SwiftParser
import Testing

@Suite("Swift symbol table")
struct SwiftSymbolTableSuite {

  @Test func lookupBindingTests() throws {
    let symbolTable = SwiftSymbolTable(parsedModuleName: "MyModule")
    let sourceFile1: SourceFileSyntax = """
      extension X.Y {
        struct Z { }
      }
      extension X {
        struct Y {}
      }
      """
    let sourceFile2: SourceFileSyntax = """
      struct X {}
      """

    symbolTable.setup([sourceFile1, sourceFile2])

    let x = try #require(symbolTable.lookupType("X", parent: nil))
    let xy = try #require(symbolTable.lookupType("Y", parent: x))
    let xyz = try #require(symbolTable.lookupType("Z", parent: xy))
    #expect(xyz.qualifiedName == "X.Y.Z")

    #expect(symbolTable.lookupType("Y", parent: nil) == nil)
    #expect(symbolTable.lookupType("Z", parent: nil) == nil)
  }
}
