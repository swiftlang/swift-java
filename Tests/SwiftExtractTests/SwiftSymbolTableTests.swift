//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftExtract
import SwiftParser
import SwiftSyntax
import Testing

@Suite("SwiftSymbolTable")
struct SwiftSymbolTableSuite {

  // ==== -----------------------------------------------------------------------
  // MARK: Lookup binding (moved from JExtractSwiftTests)

  @Test func lookupBindingTests() throws {
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
    let symbolTable = SwiftSymbolTable.setup(
      moduleName: "MyModule",
      [
        .init(syntax: sourceFile1, path: "Fake.swift"),
        .init(syntax: sourceFile2, path: "Fake2.swift"),
      ],
      config: nil,
      sourceDependencies: SourceDependencies(),
    )

    let x = try #require(symbolTable.lookupType("X", parent: nil))
    let xy = try #require(symbolTable.lookupType("Y", parent: x))
    let xyz = try #require(symbolTable.lookupType("Z", parent: xy))
    #expect(xyz.qualifiedName == "X.Y.Z")

    #expect(symbolTable.lookupType("Y", parent: nil) == nil)
    #expect(symbolTable.lookupType("Z", parent: nil) == nil)
  }

  @Test func moduleScopedLookup() throws {
    let symbolTable = makeSymbolTable(
      moduleName: "MyModule",
      sources: ["public struct MyClass {}"]
    )

    // Lookup in self-module by qualified name
    let myClass = symbolTable.lookupTopLevelNominalType("MyClass", inModule: "MyModule")
    #expect(myClass != nil)
    #expect(myClass?.qualifiedName == "MyClass")

    // Lookup in imported module (Swift)
    let swiftInt = symbolTable.lookupTopLevelNominalType("Int", inModule: "Swift")
    #expect(swiftInt != nil)
    #expect(swiftInt?.qualifiedName == "Int")

    // Lookup in unknown module returns nil
    let unknown = symbolTable.lookupTopLevelNominalType("Foo", inModule: "NoSuchModule")
    #expect(unknown == nil)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Top-level lookup by nominal kind

  @Test func topLevelLookupResolvesEachNominalKind() throws {
    let symbolTable = makeSymbolTable(sources: [
      """
      public struct S {}
      public class C {}
      public enum E { case a }
      public actor A {}
      public protocol P {}
      """
    ])

    let s = try #require(symbolTable.lookupTopLevelNominalType("S"))
    #expect(s.kind == .struct)

    let c = try #require(symbolTable.lookupTopLevelNominalType("C"))
    #expect(c.kind == .class)

    let e = try #require(symbolTable.lookupTopLevelNominalType("E"))
    #expect(e.kind == .enum)

    let a = try #require(symbolTable.lookupTopLevelNominalType("A"))
    #expect(a.kind == .actor)

    let p = try #require(symbolTable.lookupTopLevelNominalType("P"))
    #expect(p.kind == .protocol)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Nested-type lookup, multiple levels

  @Test func nestedLookupTwoLevelsDeep() throws {
    let symbolTable = makeSymbolTable(sources: [
      """
      public struct A {
        public struct B {
          public struct C {}
        }
      }
      """
    ])

    let a = try #require(symbolTable.lookupTopLevelNominalType("A"))
    let b = try #require(symbolTable.lookupNestedType("B", parent: a))
    let c = try #require(symbolTable.lookupNestedType("C", parent: b))
    #expect(c.qualifiedName == "A.B.C")

    // C is not a top-level type
    #expect(symbolTable.lookupTopLevelNominalType("C") == nil)
    // B is not nested under C
    #expect(symbolTable.lookupNestedType("B", parent: c) == nil)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Negative lookups

  @Test func unknownNamesReturnNil() throws {
    let symbolTable = makeSymbolTable(sources: [
      """
      public struct Known {
        public struct Inner {}
      }
      """
    ])

    #expect(symbolTable.lookupTopLevelNominalType("DoesNotExist") == nil)
    #expect(symbolTable.lookupTopLevelTypealias("AlsoMissing") == nil)

    let known = try #require(symbolTable.lookupTopLevelNominalType("Known"))
    #expect(symbolTable.lookupNestedType("Missing", parent: known) == nil)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Typealias resolution

  @Test func topLevelTypealiasResolvesUnderlyingType() throws {
    let symbolTable = makeSymbolTable(sources: [
      """
      public typealias Alias = Int
      """
    ])

    let alias = try #require(symbolTable.lookupTopLevelTypealias("Alias"))
    #expect(alias.name == "Alias")
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Built-in module presence

  @Test func builtInSwiftModuleIsAlwaysRegistered() throws {
    let symbolTable = makeSymbolTable(sources: ["public struct Anything {}"])

    // Same lookup, two reachable paths: implicit cross-module, and module-scoped.
    let int = try #require(symbolTable.lookupTopLevelNominalType("Int"))
    #expect(int.moduleName == "Swift")

    let intInSwift = try #require(symbolTable.lookupTopLevelNominalType("Int", inModule: "Swift"))
    #expect(intInSwift === int)

    #expect(symbolTable.lookupTopLevelNominalType("Int", inModule: "NoSuchModule") == nil)
  }

  // ==== -----------------------------------------------------------------------
  // MARK: isModuleName

  @Test func isModuleNameRecognisesOwnAndImportedModules() throws {
    let symbolTable = makeSymbolTable(moduleName: "MyModule", sources: ["public struct X {}"])

    #expect(symbolTable.isModuleName("MyModule"))
    #expect(symbolTable.isModuleName("Swift"))
    #expect(!symbolTable.isModuleName("NotAModule"))
  }
}
