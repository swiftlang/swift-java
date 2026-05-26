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

import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

/// Parsing tests for the new `--depends-on` grammar (`Module=cfg[,sources...]`).
@Suite("--depends-on grammar")
struct DependsOnGrammarTests {

  @Test("Parsing rejects empty arguments")
  func parsing_empty() {
    #expect(throws: EmptyDependsOnArgumentError.self) {
      _ = try parseDependsOnSyntax("")
    }
  }

  @Test("Module name is parsed from the LHS of '='")
  func parsing_moduleName() throws {
    // Real config files would normally exist; parseDependsOnSyntax falls back
    // to an empty Configuration when readConfiguration returns nil. Use a path
    // that's guaranteed not to exist so we exercise the fallback.
    let parsed = try parseDependsOnSyntax("MyModule=/no/such/path/swift-java.config")
    #expect(parsed.swiftModuleName == "MyModule")
  }

  @Test("Explicit ',<sources>' suffix wins over inference")
  func parsing_explicitSourcesSuffix() throws {
    let parsed = try parseDependsOnSyntax(
      "MyModule=/no/such/path/swift-java.config,/some/explicit/source/dir"
    )
    #expect(parsed.swiftSourcePaths.map(\.path) == ["/some/explicit/source/dir"])
  }

  @Test("Multiple comma-separated sources are accepted (mirrors --input-swift)")
  func parsing_multipleExplicitSources() throws {
    let parsed = try parseDependsOnSyntax(
      "MyModule=/no/such/swift-java.config,/a,/b,/c"
    )
    #expect(parsed.swiftSourcePaths.map(\.path) == ["/a", "/b", "/c"])
  }
}
