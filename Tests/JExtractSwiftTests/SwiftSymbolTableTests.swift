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

@_spi(Testing) import JExtractSwiftLib
import SwiftExtract
import SwiftJavaConfigurationShared
import SwiftParser
import SwiftSyntax
import Testing

@Suite("Swift symbol table")
struct SwiftSymbolTableSuite {

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
