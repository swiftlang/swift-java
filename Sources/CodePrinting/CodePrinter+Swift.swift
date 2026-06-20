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

// ==== -----------------------------------------------------------------------
// MARK: CodePrinter — Swift-language helpers

extension CodePrinter where Language == SwiftLanguage {

  /// Print a Swift `if <condition> { … }` block.
  /// The condition is emitted verbatim, without surrounding parentheses
  /// (Swift convention).
  public mutating func printIfBlock(
    _ condition: Any,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line,
    body: (inout CodePrinter) throws -> Void
  ) rethrows {
    try printBraceBlock("if \(condition)", function: function, file: file, line: line, body: body)
  }

  /// Print a Swift `guard <condition> else { … }` block.
  public mutating func printGuardBlock(
    _ condition: Any,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line,
    body: (inout CodePrinter) throws -> Void
  ) rethrows {
    try printBraceBlock("guard \(condition) else", function: function, file: file, line: line, body: body)
  }
}
