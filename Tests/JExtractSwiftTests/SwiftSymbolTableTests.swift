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

@_spi(Testing) import JExtractSwiftLib
import SwiftJavaConfigurationShared
import SwiftParser
import SwiftSyntax
import Testing

@Suite("Swift symbol table")
struct SwiftSymbolTableSuite {

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
      log: Logger(label: "swift-java", logLevel: .critical),
    )

    let x = try #require(symbolTable.lookupType("X", parent: nil))
    let xy = try #require(symbolTable.lookupType("Y", parent: x))
    let xyz = try #require(symbolTable.lookupType("Z", parent: xy))
    #expect(xyz.qualifiedName == "X.Y.Z")

    #expect(symbolTable.lookupType("Y", parent: nil) == nil)
    #expect(symbolTable.lookupType("Z", parent: nil) == nil)
  }

  @Test
  func resolveSelfModuleName() throws {
    try assertOutput(
      input: """
        import Foundation
        public struct MyValue {}

        public func fullyQualifiedType() -> MyModule.MyValue
        public func fullyQualifiedType2() -> Foundation.Data
        """,
      .jni,
      .java,
      swiftModuleName: "MyModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static MyValue fullyQualifiedType(",
        "public static org.swift.swiftkit.core.foundation.Data fullyQualifiedType2(",
      ],
    )
  }

  @Test(arguments: [JExtractGenerationMode.jni, .ffm])
  func resolveSelfModuleName_moduleDuplicatedName(mode: JExtractGenerationMode) throws {
    try assertOutput(
      input: """
        public struct MyModule {
          public struct MyValue {}
        }

        public func fullyQualifiedType() -> MyModule.MyModule.MyValue
        """,
      mode,
      .java,
      swiftModuleName: "MyModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static MyModule.MyValue fullyQualifiedType("
      ],
    )
  }

  @Test func moduleScopedLookup() throws {
    let sourceFile: SourceFileSyntax = """
      public struct MyClass {}
      """
    let symbolTable = SwiftSymbolTable.setup(
      moduleName: "MyModule",
      [
        .init(syntax: sourceFile, path: "Fake.swift")
      ],
      config: nil,
      log: Logger(label: "swift-java", logLevel: .critical),
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

  @Test(arguments: [JExtractGenerationMode.jni, .ffm])
  func resolveQualifiedTypesInFunctionSignatures(mode: JExtractGenerationMode) throws {
    try assertOutput(
      input: """
        public struct MySwiftClass {
          public init() {}
        }

        public func factory(len: Swift.Int, cap: Swift.Int) -> MyModule.MySwiftClass
        """,
      mode,
      .java,
      swiftModuleName: "MyModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static MySwiftClass factory("
      ],
    )
  }

  @Test(arguments: [JExtractGenerationMode.jni, .ffm])
  func resolveQualifiedNestedTypesInFunctionSignatures(mode: JExtractGenerationMode) throws {
    try assertOutput(
      input: """
        public struct MySwiftClass {
          public struct Nested {
            public init() {}
          }
        }

        public func factory(len: Swift.Int, cap: Swift.Int) -> MyModule.MySwiftClass.Nested
        """,
      mode,
      .java,
      swiftModuleName: "MyModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static MySwiftClass.Nested factory("
      ],
    )
  }

  @Test(arguments: [JExtractGenerationMode.jni, .ffm])
  func resolveQualifiedTypesShadowingModule(mode: JExtractGenerationMode) throws {
    try assertOutput(
      input: """
        public struct MyModule { // shadowing module MyModule
          public init() {}
        }

        public func factory(len: Swift.Int, cap: Swift.Int) -> MyModule
        """,
      mode,
      .java,
      swiftModuleName: "MyModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static MyModule factory("
      ],
    )
  }
}
