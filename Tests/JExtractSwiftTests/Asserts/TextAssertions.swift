//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JExtractSwift
import Testing
import struct Foundation.CharacterSet

func assertOutput(
  dump: Bool = false,
  _ got: String,
  expected: String,
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column
) {
  let gotLines = got.split(separator: "\n")
  let expectedLines = expected.split(separator: "\n")

  var diffLineNumbers: [Int] = []

  for (no, (g, e)) in zip(gotLines, expectedLines).enumerated() {
    if g.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count == 0
      || e.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count == 0
    {
      continue
    }

    let ge = g.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    let ee = e.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    if ge.commonPrefix(with: ee) != ee {
      //      print("")
      //      print("[\(file):\(line)] " + "Difference found on line: \(no + 1)!".red)
      //      print("Expected @ \(file):\(Int(line) + no + 3 /*formatting*/ + 1):")
      //      print(e.yellow)
      //      print("Got instead:")
      //      print(g.red)

      diffLineNumbers.append(no)

      let sourceLocation = SourceLocation(
        fileID: fileID, filePath: filePath, line: line, column: column)
      #expect(ge == ee, sourceLocation: sourceLocation)
    }

  }

  let hasDiff = diffLineNumbers.count > 0
  if hasDiff || dump{
    print("")
    if hasDiff {
      print("error: Number of not matching lines: \(diffLineNumbers.count)!".red)

      print("==== ---------------------------------------------------------------")
      print("Expected output:")
      for (n, e) in expectedLines.enumerated() {
        print("\(e)".yellow(if: diffLineNumbers.contains(n)))
      }
    }

    print("==== ---------------------------------------------------------------")
    print("Got output:")
    for (n, g) in gotLines.enumerated() {
      print("\(g)".red(if: diffLineNumbers.contains(n)))
    }
    print("==== ---------------------------------------------------------------\n")
  }
}
