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

import CodePrinting
import Testing

@Suite("CodePrinter.inlineCommentStyle")
struct InlineCommentStyleSuite {

  // ==== ----------------------------------------------------------------------
  // MARK: Default behavior is `//`

  @Test func defaultStyleEmitsSlashSlashSourceLocation() {
    var p = SwiftPrinter()
    p.print("hello", .sloc, function: "fn", file: "F.swift", line: 1)

    #expect(p.contents.contains("// fn @ F.swift:1"))
    #expect(!p.contents.contains("# fn @ F.swift:1"))
  }

  // ==== ----------------------------------------------------------------------
  // MARK: `.hash` flips comment lead

  @Test func hashStyleEmitsHashSourceLocation() {
    var p = SwiftPrinter()
    p.inlineCommentStyle = .hash
    p.print("hello", .sloc, function: "fn", file: "F.swift", line: 1)

    #expect(p.contents.contains("# fn @ F.swift:1"))
    #expect(!p.contents.contains("// fn @ F.swift:1"))
  }

  @Test func hashStyleFlipsPrintSeparatorBanner() {
    var p = SwiftPrinter()
    p.inlineCommentStyle = .hash
    p.printSeparator("section")

    #expect(p.contents.contains("# ===="))
    #expect(p.contents.contains("# section"))
    #expect(!p.contents.contains("// ===="))
  }

  // ==== ----------------------------------------------------------------------
  // MARK: emitSourceLocations off still respects style

  @Test func emitSourceLocationsOffSuppressesTrailerRegardlessOfStyle() {
    var p = SwiftPrinter()
    p.emitSourceLocations = false
    p.inlineCommentStyle = .hash
    p.print("hello", .sloc, function: "fn", file: "F.swift", line: 1)

    #expect(!p.contents.contains("# fn @"))
    #expect(!p.contents.contains("// fn @"))
    #expect(p.contents.hasSuffix("hello\n"))
  }
}

@Suite("JavaPrinter.printJavadocComment")
struct PrintJavadocCommentSuite {

  // ==== ----------------------------------------------------------------------
  // MARK: Pre-Java-23: classic /** ... */ block

  @Test func classicBlockShapeForOlderJava() {
    var p = JavaPrinter()
    p.emitSourceLocations = false
    p.options.sourceVersion = 17
    p.printJavadocComment("First line.\nSecond line.")

    let out = p.contents
    #expect(out.contains("/**"))
    #expect(out.contains(" * First line."))
    #expect(out.contains(" * Second line."))
    #expect(out.contains(" */"))
    #expect(!out.contains("///"))
  }

  @Test func blankLineBecomesBareStarSeparator() {
    var p = JavaPrinter()
    p.emitSourceLocations = false
    p.options.sourceVersion = 17
    p.printJavadocComment("Para1\n\nPara2")

    // Blank paragraph separators render as a bare ` *` (no trailing space)
    let lines = p.contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    #expect(lines.contains(" *"))
    #expect(!lines.contains(" * "))
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Java 23+: Markdown line comments (JEP 467)

  @Test func markdownLineShapeFromJava23() {
    var p = JavaPrinter()
    p.emitSourceLocations = false
    p.options.sourceVersion = 23
    p.printJavadocComment("First line.\nSecond line.")

    let out = p.contents
    #expect(out.contains("/// First line."))
    #expect(out.contains("/// Second line."))
    #expect(!out.contains("/**"))
    #expect(!out.contains(" */"))
  }

  @Test func markdownBlankLineIsBareTripleSlash() {
    // JEP 467 - Markdown Documentation Comments (final in Java 23):
    // https://openjdk.org/jeps/467
    var p = JavaPrinter()
    p.emitSourceLocations = false
    p.options.sourceVersion = 23
    p.printJavadocComment("A\n\nB")

    let lines = p.contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    #expect(lines.contains("///"))
    #expect(!lines.contains("/// "))
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Default version uses classic block

  @Test func defaultJavaVersionUsesClassicBlock() {
    var p = JavaPrinter() // default sourceVersion is 8
    p.emitSourceLocations = false
    p.printJavadocComment("hello")

    #expect(p.contents.contains("/**"))
    #expect(p.contents.contains(" * hello"))
    #expect(p.contents.contains(" */"))
  }
}
