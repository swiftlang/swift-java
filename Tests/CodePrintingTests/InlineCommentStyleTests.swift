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
    var p = CodePrinter()
    p.print("hello", .sloc, function: "fn", file: "F.swift", line: 1)

    #expect(p.contents.contains("// fn @ F.swift:1"))
    #expect(!p.contents.contains("# fn @ F.swift:1"))
  }

  // ==== ----------------------------------------------------------------------
  // MARK: `.hash` flips comment lead

  @Test func hashStyleEmitsHashSourceLocation() {
    var p = CodePrinter()
    p.inlineCommentStyle = .hash
    p.print("hello", .sloc, function: "fn", file: "F.swift", line: 1)

    #expect(p.contents.contains("# fn @ F.swift:1"))
    #expect(!p.contents.contains("// fn @ F.swift:1"))
  }

  @Test func hashStyleFlipsPrintSeparatorBanner() {
    var p = CodePrinter()
    p.inlineCommentStyle = .hash
    p.printSeparator("section")

    #expect(p.contents.contains("# ===="))
    #expect(p.contents.contains("# section"))
    #expect(!p.contents.contains("// ===="))
  }

  // ==== ----------------------------------------------------------------------
  // MARK: emitSourceLocations off still respects style

  @Test func emitSourceLocationsOffSuppressesTrailerRegardlessOfStyle() {
    var p = CodePrinter()
    p.emitSourceLocations = false
    p.inlineCommentStyle = .hash
    p.print("hello", .sloc, function: "fn", file: "F.swift", line: 1)

    #expect(!p.contents.contains("# fn @"))
    #expect(!p.contents.contains("// fn @"))
    #expect(p.contents.hasSuffix("hello\n"))
  }
}
