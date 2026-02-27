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
      log: Logger(label: "swift-java", logLevel: .critical)
    )

    let x = try #require(symbolTable.lookupType("X", parent: nil))
    let xy = try #require(symbolTable.lookupType("Y", parent: x))
    let xyz = try #require(symbolTable.lookupType("Z", parent: xy))
    #expect(xyz.qualifiedName == "X.Y.Z")

    #expect(symbolTable.lookupType("Y", parent: nil) == nil)
    #expect(symbolTable.lookupType("Z", parent: nil) == nil)
  }

  @Test(arguments: [JExtractGenerationMode.jni, .ffm])
  func resolveSelfModuleName(mode: JExtractGenerationMode) throws {
    try assertOutput(
      input: """
        import Foundation
        public struct MyValue {}

        public func fullyQualifiedType() -> MyModule.MyValue
        public func fullyQualifiedType2() -> Foundation.Data
        """,
      mode,
      .java,
      swiftModuleName: "MyModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static MyValue fullyQualifiedType(",
        "public static Data fullyQualifiedType2(",
      ]
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
      ]
    )
  }
}
