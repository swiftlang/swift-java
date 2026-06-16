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
import SwiftParser
import SwiftSyntax

/// Build a `SwiftSymbolTable` from inline Swift source strings.
///
/// Each entry in `sources` becomes a synthetic `Test<i>.swift` file feeding
/// the primary module being analysed.
func makeSymbolTable(
  moduleName: String = "TestModule",
  sources: [String],
  sourceDependencies: SourceDependencies = SourceDependencies()
) -> SwiftSymbolTable {
  let inputs: [SwiftInputFile] = sources.enumerated().map { (i, src) in
    SwiftInputFile(
      syntax: Parser.parse(source: src),
      path: "Test\(i).swift"
    )
  }
  return SwiftSymbolTable.setup(
    moduleName: moduleName,
    inputs,
    config: nil,
    sourceDependencies: sourceDependencies,
  )
}

/// Convenience: build a single `SwiftInputFile` from a source string.
func makeInputFile(_ source: String, path: String = "Dep.swift") -> SwiftInputFile {
  SwiftInputFile(syntax: Parser.parse(source: source), path: path)
}
