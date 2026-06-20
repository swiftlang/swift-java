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

@Suite("CodePrinter.printGuardBlock")
struct PrintGuardBlockSuite {

  @Test func emitsGuardElseBlockWithoutCondParens() {
    var p = CodePrinter()
    p.emitSourceLocations = false
    p.printGuardBlock("let x = optional") { inner in
      inner.print("return nil")
    }

    let out = p.contents
    #expect(out.contains("guard let x = optional else {"))
    #expect(out.contains("  return nil"))
    #expect(out.contains("}"))
    #expect(!out.contains("guard (let x = optional) else"))
  }

  @Test func nestsAndIndentsBody() {
    var p = CodePrinter()
    p.emitSourceLocations = false
    p.printBraceBlock("func foo()") { fn in
      fn.printGuardBlock("let v = maybe") { g in
        g.print("return")
      }
    }

    let lines = p.contents.split(separator: "\n", omittingEmptySubsequences: false)
    let returnLine = lines.first { $0.contains("return") }
    #expect(
      returnLine?.hasPrefix("    ") == true,
      "guard body should be indented two levels under the enclosing func"
    )
  }
}
