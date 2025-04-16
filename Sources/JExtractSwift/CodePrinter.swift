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

import Foundation

public struct CodePrinter {
  var contents: String = ""

  var verbose: Bool = false
  let log = Logger(label: "printer", logLevel: .info)

  var indentationDepth: Int = 0 {
    didSet {
      indentationText = String(repeating: indentationPart, count: indentationDepth)
    }
  }

  /// String to use for one level of indentationDepth.
  public var indentationPart: String = "  " {
    didSet {
      indentationText = String(repeating: indentationPart, count: indentationDepth)
    }
  }
  public var indentationText: String = ""
  /// If true, next print() should starts with indentation.
  var atNewline = true

  public static func toString(_ block: (inout CodePrinter) throws -> ()) rethrows -> String {
    var printer = CodePrinter()
    try block(&printer)
    return printer.finalize()
  }

  var mode: PrintMode
  public enum PrintMode {
    case accumulateAll
    case flushToFileOnWrite
  }
  public init(mode: PrintMode = .flushToFileOnWrite) {
    self.mode = mode
  }

  internal mutating func append(_ text: String) {
    contents.append(text)
    if self.verbose {
      Swift.print(text, terminator: "")
    }
  }

  internal mutating func append<S>(contentsOf text: S)
  where S: Sequence, S.Element == Character {
    contents.append(contentsOf: text)
    if self.verbose {
      for t in text {
        Swift.print(t, terminator: "")
      }
    }
  }

  public mutating func printTypeDecl(
    _ text: Any,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line,
    body: (inout CodePrinter) -> ()
  ) {
    print("\(text) {")
    indent()
    body(&self)
    outdent()
    print("}", .sloc, function: function, file: file, line: line)
  }

  public mutating func printParts(
    _ parts: String...,
    terminator: PrinterTerminator = .newLine,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line
  ) {
    for part in parts {
      guard part.trimmingCharacters(in: .whitespacesAndNewlines).count != 0 else {
        continue
      }

      self.print(part, terminator, function: function, file: file, line: line)
    }
  }

  /// Print a plain newline, e.g. to separate declarations.
  public mutating func println(
    _ terminator: PrinterTerminator = .newLine,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line
  ) {
    print("")
  }

  public mutating func print(
    _ text: Any,
    _ terminator: PrinterTerminator = .newLine,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line
  ) {
    let lines = "\(text)".split(separator: "\n", omittingEmptySubsequences: false)
    var first = true
    for line in lines {
      if !first {
        append("\n")
        append(indentationText)
      } else {
        if atNewline {
          append(indentationText)
        }
        first = false
      }
      append(contentsOf: line)
    }

    if terminator == .sloc {
      append(" // \(function) @ \(file):\(line)\n")
      atNewline = true
    } else {
      append(terminator.rawValue)
      atNewline = terminator == .newLine || terminator == .commaNewLine
    }
  }

  public mutating func start(_ text: String) {
    print(text, .continue)
  }

  // TODO: remove this in real mode, this just helps visually while working on it
  public mutating func printSeparator(_ text: String) {
    // TODO: actually use the indentationDepth
    print(
      """
      // ==== --------------------------------------------------
      // \(text)

      """
    )
  }

  public mutating func finalize() -> String {
    // assert(indentationDepth == 0, "Finalize CodePrinter with non-zero indentationDepth. Text was: \(contents)") // FIXME: do this
    defer { contents = "" }

    return contents
  }

  public mutating func indent(file: String = #fileID, line: UInt = #line, function: String = #function) {
    indentationDepth += 1
    log.trace("Indent => \(indentationDepth)", file: file, line: line, function: function)
  }

  public mutating func outdent(file: String = #fileID, line: UInt = #line, function: String = #function) {
    indentationDepth -= 1
    log.trace("Outdent => \(indentationDepth)", file: file, line: line, function: function)
    assert(indentationDepth >= 0, "Outdent beyond zero at [\(file):\(line)](\(function))")
  }

  public var isEmpty: Bool {
    self.contents.isEmpty
  }

  public mutating func dump(file: String = #fileID, line: UInt = #line) {
    Swift.print("// CodePrinter.dump @ \(file):\(line)")
    Swift.print(contents)
  }

}

public enum PrinterTerminator: String {
  case newLine = "\n"
  case space = " "
  case commaSpace = ", "
  case commaNewLine = ",\n"
  case `continue` = ""
  case sloc = "// <source location>"

  public static func parameterSeparator(_ isLast: Bool) -> Self {
    if isLast {
      .continue
    } else {
      .commaSpace
    }
  }

  public static func parameterNewlineSeparator(_ isLast: Bool) -> Self {
    if isLast {
      .newLine
    } else {
      .commaNewLine
    }
  }
}

extension CodePrinter {
  
  /// - Returns: the output path of the generated file, if any (i.e. not in accumulate in memory mode)
  package mutating func writeContents(
    outputDirectory: String,
    javaPackagePath: String?,
    filename: String
  ) throws -> URL? {
    guard self.mode != .accumulateAll else {
      // if we're accumulating everything, we don't want to finalize/flush any contents
      // let's mark that this is where a write would have happened though:
      print("// ^^^^ Contents of: \(outputDirectory)/\(filename)")
      return nil
    }

    let contents = finalize()
    if outputDirectory == "-" {
      print(
        "// ==== ---------------------------------------------------------------------------------------------------"
      )
      if let javaPackagePath {
        print("// \(javaPackagePath)/\(filename)")
      } else {
        print("// \(filename)")
      }
      print(contents)
      return nil
    }

    let targetDirectory = [outputDirectory, javaPackagePath].compactMap { $0 }.joined(separator: PATH_SEPARATOR)
    log.trace("Prepare target directory: \(targetDirectory)")
    try FileManager.default.createDirectory(
      atPath: targetDirectory, withIntermediateDirectories: true)

    let outputPath = Foundation.URL(fileURLWithPath: targetDirectory).appendingPathComponent(filename)
    try contents.write(
      to: outputPath,
      atomically: true,
      encoding: .utf8
    )
    
    return outputPath
  }

}
