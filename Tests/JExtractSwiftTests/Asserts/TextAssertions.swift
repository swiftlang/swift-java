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
  _ translator: Swift2JavaTranslator,
  input: String,
  detectChunkByInitialLines: Int = 4,
  expectedChunks: [String],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column
) {
  try! translator.analyze(swiftInterfacePath: "/fake/Fake.swiftinterface", text: input)

  let output = CodePrinter.toString { printer in
    for ty in translator.importedTypes.values {
      translator.printImportedNominalType(&printer, ty)
      printer.print("\n")
      printer.print("// ======================================================================")
      printer.print("// ======================================================================")
      printer.print("\n")
    }
    translator.printModule(&printer)
  }

  let gotLines = output.split(separator: "\n")
  for expected in expectedChunks {
    let expectedLines = expected.split(separator: "\n")

    var matchingOutputOffset = 0
    let expectedInitialMatchingLines = expectedLines[0..<detectChunkByInitialLines]
      .map({$0.trimmingCharacters(in: .whitespacesAndNewlines)})
      .joined(separator: "\n")
    for offset in 0..<gotLines.count where gotLines.count > (offset+detectChunkByInitialLines) {
      let textLinesAtOffset = gotLines[offset..<offset+detectChunkByInitialLines]
        .map({$0.trimmingCharacters(in: .whitespacesAndNewlines)})
        .joined(separator: "\n")

//      print("CHECKING GOT@\(offset)->\(offset + detectChunkByInitialLines) ==========")
//      print(textLinesAtOffset)
//      print("AGAINST EXPECTED@\(0)->\(expectedInitialMatchingLines) ==========")
//      print(expectedInitialMatchingLines)
//      print("")
//      print("")

      if textLinesAtOffset == expectedInitialMatchingLines {
        matchingOutputOffset = offset
//        print("MATCHED \(matchingOutputOffset)")
        break
      }
    }

    var diffLineNumbers: [Int] = []

    for (no, (g, e)) in zip(gotLines.dropFirst(matchingOutputOffset), expectedLines).enumerated() {
      if g.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count == 0
           || e.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count == 0 {
        continue
      }

      let ge = g.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      let ee = e.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
      if ge.commonPrefix(with: ee) != ee {
        diffLineNumbers.append(no + matchingOutputOffset)

        let sourceLocation = SourceLocation(
          fileID: fileID, filePath: filePath, line: line, column: column)
        #expect(ge == ee, sourceLocation: sourceLocation)
      }
    }

    let hasDiff = diffLineNumbers.count > 0
    if hasDiff || dump {
      print("")
      if hasDiff {
        print("error: Number of not matching lines: \(diffLineNumbers.count)!".red)

        print("==== ---------------------------------------------------------------")
        print("Expected output:")
        for (n, e) in expectedLines.enumerated() {
          print("\(n): \(e)".yellow(if: diffLineNumbers.map({$0 - matchingOutputOffset}).contains(n)))
        }
      }

      print("==== ---------------------------------------------------------------")
      print("Got output:")
      let surroundingContext = 5
      let printFromLineNo = matchingOutputOffset
      let printToLineNo = matchingOutputOffset + expectedLines.count
      for (n, g) in gotLines.enumerated() where n >= printFromLineNo && n <= printToLineNo {
        print("\(n): \(g)".red(if: diffLineNumbers.contains(n)))
      }
      print("==== ---------------------------------------------------------------\n")
    }
  }
}

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
         || e.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count == 0 {
      continue
    }

    let ge = g.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    let ee = e.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    if ge.commonPrefix(with: ee) != ee {
      diffLineNumbers.append(no)

      let sourceLocation = SourceLocation(
        fileID: fileID, filePath: filePath, line: line, column: column)
      #expect(ge == ee, sourceLocation: sourceLocation)
    }

  }

  let hasDiff = diffLineNumbers.count > 0
  if hasDiff || dump {
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
