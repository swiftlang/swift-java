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
// MARK: CodePrinter - Java-language helpers

extension CodePrinter where Language == JavaLanguage {

  /// Print a Java `if (<condition>) { ... }` block.
  public mutating func printIfBlock(
    _ condition: Any,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line,
    body: (inout CodePrinter) throws -> Void
  ) rethrows {
    try printBraceBlock("if (\(condition))", function: function, file: file, line: line, body: body)
  }

  /// Print a Javadoc comment.
  ///
  /// Shape depends on `options.sourceVersion`:
  /// - Java 23+: Markdown-style line comments (`///`) based on https://openjdk.org/jeps/467
  ///   `{@code X}` inline tags are rewritten to Markdown backticks (`` `X` ``).
  /// - Earlier versions: classic `/** ... */` block. Single-line input is
  ///   collapsed to `/** text */`; multi-line input keeps each body line
  ///   prefixed by ` * ` (just ` *` for blank paragraph separators).
  ///
  /// Pass paragraph breaks as blank lines (`\n\n`) inside `text`.
  public mutating func printJavadocComment(_ text: String) {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    if options.sourceVersion >= 23 {
      for line in lines {
        let rewritten = Self.rewriteInlineCodeTagsToMarkdown(String(line))
        print(rewritten.isEmpty ? "///" : "/// \(rewritten)")
      }
    } else if lines.count == 1 {
      print("/** \(lines[0]) */")
    } else {
      print("/**")
      for line in lines {
        print(line.isEmpty ? " *" : " * \(line)")
      }
      print(" */")
    }
  }

  /// Rewrite `{@code X}` inline Javadoc tags to Markdown backtick spans
  /// (`` `X` ``) for JEP 467 `///` comments.
  static func rewriteInlineCodeTagsToMarkdown(_ line: String) -> String {
    var result = ""
    var remaining = line[...]
    while let start = remaining.range(of: "{@code ") {
      result.append(contentsOf: remaining[..<start.lowerBound])
      let afterOpen = start.upperBound
      guard let closeIdx = remaining[afterOpen...].firstIndex(of: "}") else {
        // No closing brace, bail out and keep the tail as-is
        result.append(contentsOf: remaining[start.lowerBound...])
        return result
      }
      result.append("`")
      result.append(contentsOf: remaining[afterOpen..<closeIdx])
      result.append("`")
      remaining = remaining[remaining.index(after: closeIdx)...]
    }
    result.append(contentsOf: remaining)
    return result
  }
}
