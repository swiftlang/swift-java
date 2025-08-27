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

import JExtractSwiftLib
import Testing
import SwiftJavaConfigurationShared
import struct Foundation.CharacterSet

enum RenderKind {
  case swift
  case java
}

func assertOutput(
  dump: Bool = false,
  input: String,
  config: Configuration? = nil,
  _ mode: JExtractGenerationMode,
  _ renderKind: RenderKind,
  swiftModuleName: String = "SwiftModule",
  detectChunkByInitialLines _detectChunkByInitialLines: Int = 4,
  javaClassLookupTable: [String: String] = [:],
  expectedChunks: [String],
  fileID: String = #fileID,
  filePath: String = #filePath,
  line: Int = #line,
  column: Int = #column
) throws {
  var config = config ?? Configuration()
  config.swiftModule = swiftModuleName
  let translator = Swift2JavaTranslator(config: config)
  translator.dependenciesClasses = Array(javaClassLookupTable.keys)

  try! translator.analyze(file: "/fake/Fake.swiftinterface", text: input)

  let output: String
  var printer: CodePrinter = CodePrinter(mode: .accumulateAll)
  switch mode {
  case .ffm:
    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: translator,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    switch renderKind {
    case .swift:
      try generator.writeSwiftThunkSources(printer: &printer)
    case .java:
      try generator.writeExportedJavaSources(printer: &printer)
    }

  case .jni:
    let generator = JNISwift2JavaGenerator(
      config: config,
      translator: translator,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake",
      javaClassLookupTable: javaClassLookupTable
    )

    switch renderKind {
    case .swift:
      try generator.writeSwiftThunkSources(&printer)
    case .java:
      try generator.writeExportedJavaSources(&printer)
    }
  }
  output = printer.finalize()

  let gotLines = output.split(separator: "\n").filter { l in
    l.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count > 0
  }
  for expectedChunk in expectedChunks {
    let expectedLines = expectedChunk.split(separator: "\n")
    let detectChunkByInitialLines = min(expectedLines.count, _detectChunkByInitialLines)
    precondition(detectChunkByInitialLines > 0, "Chunk size to detect cannot be zero lines!")

    var matchingOutputOffset: Int? = nil
    let expectedInitialMatchingLines = expectedLines[0..<min(expectedLines.count, detectChunkByInitialLines)]
      .map({$0.trimmingCharacters(in: .whitespacesAndNewlines)})
      .joined(separator: "\n")

    for lineOffset in 0..<gotLines.count where gotLines.count > (lineOffset+detectChunkByInitialLines) {
      let textLinesAtOffset = gotLines[lineOffset..<lineOffset+detectChunkByInitialLines]
        .map({$0.trimmingCharacters(in: .whitespacesAndNewlines)})
        .joined(separator: "\n")
      if textLinesAtOffset == expectedInitialMatchingLines {
        matchingOutputOffset = lineOffset
        break
      }
    }

    let sourceLocation = SourceLocation(
      fileID: fileID, filePath: filePath, line: line, column: column)

    var diffLineNumbers: [Int] = []
    guard let matchingOutputOffset else {
      print("error: Output did not contain expected chunk!".red)
      
      print("==== ---------------------------------------------------------------")
      print("Expected output:")
      print("'\(expectedChunk.yellow)'")
      print("==== ---------------------------------------------------------------")
      print("Got output:")
      print(output)
      print("==== ---------------------------------------------------------------")
      
      #expect(output.contains(expectedChunk), sourceLocation: sourceLocation)
      continue
    }

    var currentExpectedLine: Int = 0
    var currentGotLine: Int = matchingOutputOffset

    outer: while currentExpectedLine < expectedLines.count {
      let expectedLine = expectedLines[currentExpectedLine].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

      if expectedLine == "..." {
        // Ignore the rest of output, if last line is placeholder.
        guard currentExpectedLine != (expectedLines.count - 1) else {
          break
        }

        let nextLine = expectedLines[currentExpectedLine + 1].trimmingCharacters(in: .whitespacesAndNewlines)
        while currentGotLine < gotLines.count {
          let gottenLine = gotLines[currentGotLine].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if gottenLine.commonPrefix(with: nextLine) == nextLine {
            currentExpectedLine += 2
            break
          } else if nextLine == "..." {
            // Skip any following "..."
            currentExpectedLine += 1
            break
          } else {
            currentGotLine += 1
          }

          if currentGotLine == gotLines.count {
            diffLineNumbers.append(currentExpectedLine + matchingOutputOffset + 1)
            Issue.record("Expected to find '\(nextLine)' after wildcard, but end of file reached.", sourceLocation: sourceLocation)
            break outer
          }
        }

        currentGotLine += 1
      } else {
        let gottenLine = gotLines[currentGotLine].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if gottenLine.commonPrefix(with: expectedLine) != expectedLine {
          diffLineNumbers.append(currentExpectedLine + matchingOutputOffset)

          #expect(gottenLine == expectedLine, sourceLocation: sourceLocation)
        }
        currentGotLine += 1
        currentExpectedLine += 1
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
      let printFromLineNo = matchingOutputOffset
      for (n, g) in gotLines.enumerated() where n >= printFromLineNo {
        let baseLine = "\(n): \(g)"
        var line = baseLine
        if diffLineNumbers.contains(n) {
          line += "\n"
          let leadingCount = "\(n): ".count
          let message = "\(String(repeating: " ", count: leadingCount))\(String(repeating: "^", count: 8)) EXPECTED MATCH OR SEARCHING FROM HERE "
          line += "\(message)\(String(repeating: "^", count: max(0, line.count - message.count)))"
          line = line.red
        }
        print(line)
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
  let gotLines = got.split(separator: "\n").filter { l in
    l.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count > 0
  }
  let expectedLines = expected.split(separator: "\n").filter { l in
    l.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).count > 0
  }

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
