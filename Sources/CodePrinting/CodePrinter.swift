//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// ==== -----------------------------------------------------------------------
// MARK: CodePrinter

public struct CodePrinter {
  public var contents: String = ""

  public var verbose: Bool = false

  public var indentationDepth: Int = 0 {
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
  public var atNewline = true

  public static func toString(_ block: (inout CodePrinter) throws -> Void) rethrows -> String {
    var printer = CodePrinter()
    try block(&printer)
    return printer.finalize()
  }

  public var mode: PrintMode
  public enum PrintMode {
    case accumulateAll
    case flushToFileOnWrite
  }
  public init(mode: PrintMode = .flushToFileOnWrite) {
    self.mode = mode
  }

  public mutating func append(_ text: String) {
    contents.append(text)
    if self.verbose {
      Swift.print(text, terminator: "")
    }
  }

  public mutating func append<S>(contentsOf text: S)
  where S: Sequence, S.Element == Character {
    contents.append(contentsOf: text)
    if self.verbose {
      for t in text {
        Swift.print(t, terminator: "")
      }
    }
  }

  public mutating func printHashIfBlock(
    _ header: Any,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line,
    body: (inout CodePrinter) throws -> Void
  ) rethrows {
    print("#if \(header)")
    indent()
    try body(&self)
    outdent()
    print("#endif // end of \(header)", .sloc, function: function, file: file, line: line)
  }

  public mutating func printBraceBlock(
    _ header: Any,
    parameters: [String]? = nil,
    _ terminator: PrinterTerminator = .sloc,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line,
    body: (inout CodePrinter) throws -> Void
  ) rethrows {
    print("\(header) {", .continue)
    if let parameters {
      print(" (\(parameters.joined(separator: ", "))) in", .continue)
    }
    println()
    indent()
    try body(&self)
    outdent()
    print("}", terminator, function: function, file: file, line: line)
  }

  public mutating func printIfBlock(
    _ condition: Any,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line,
    body: (inout CodePrinter) throws -> Void
  ) rethrows {
    try printBraceBlock("if (\(condition))", function: function, file: file, line: line, body: body)
  }

  public mutating func printParts(
    _ parts: String...,
    terminator: PrinterTerminator = .newLine,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line
  ) {
    for part in parts {
      guard !part.allSatisfy(\.isWhitespace) else {
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

  public mutating func printSeparator(_ text: String) {
    assert(!text.contains(where: \.isNewline))
    print(
      """

      // ==== --------------------------------------------------
      // \(text)

      """
    )
  }

  public mutating func finalize() -> String {
    defer { contents = "" }
    return contents
  }

  public mutating func indent(file: String = #fileID, line: UInt = #line, function: String = #function) {
    indentationDepth += 1
  }

  public mutating func outdent(file: String = #fileID, line: UInt = #line, function: String = #function) {
    indentationDepth -= 1
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

// ==== -----------------------------------------------------------------------
// MARK: PrinterTerminator

public enum PrinterTerminator: String {
  case newLine = "\n"
  case space = " "
  case commaSpace = ", "
  case commaNewLine = ",\n"
  case `continue` = ""
  case sloc = "// <source location>"
  case semicolonNewLine = ";\n"

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

// ==== -----------------------------------------------------------------------
// MARK: PATH_SEPARATOR

#if os(Windows)
public let PATH_SEPARATOR = "\\"
#else
public let PATH_SEPARATOR = "/"
#endif

// ==== -----------------------------------------------------------------------
// MARK: CodePrinter + writeContents

extension CodePrinter {

  /// Write the accumulated contents to a file in the given output directory.
  ///
  /// - Returns: the output path of the generated file, if any (i.e. not in accumulate-in-memory mode)
  public mutating func writeContents(
    outputDirectory _outputDirectory: String,
    javaPackagePath: String?,
    filename _filename: String
  ) throws -> URL? {
    // We handle 'filename' that has a path, since that simplifies passing
    // paths from root output directory enormously. This just moves the
    // directory parts into the output directory part in order for us to
    // create the sub-directories.
    let outputDirectory: String
    let filename: String
    if _filename.contains(PATH_SEPARATOR) {
      let parts = _filename.split(separator: PATH_SEPARATOR)
      outputDirectory = _outputDirectory + PATH_SEPARATOR + parts.dropLast().joined(separator: PATH_SEPARATOR)
      filename = "\(parts.last!)"
    } else {
      outputDirectory = _outputDirectory
      filename = _filename
    }

    guard self.mode != .accumulateAll else {
      // if we're accumulating everything, we don't want to finalize/flush
      // any contents; let's mark that this is where a write would have
      // happened though:
      print("// ^^^^ Contents of: \(outputDirectory)\(PATH_SEPARATOR)\(filename)")
      return nil
    }

    let contents = finalize()
    if outputDirectory == "-" {
      print(
        "// ==== ---------------------------------------------------------------------------------------------------"
      )
      if let javaPackagePath {
        print("// \(javaPackagePath)\(PATH_SEPARATOR)\(filename)")
      } else {
        print("// \(filename)")
      }
      print(contents)
      return nil
    }

    let targetDirectory = [outputDirectory, javaPackagePath].compactMap { $0 }.joined(separator: PATH_SEPARATOR)
    do {
      try FileManager.default.createDirectory(
        atPath: targetDirectory,
        withIntermediateDirectories: true
      )
    } catch {
      throw error
    }

    let outputPath = URL(fileURLWithPath: targetDirectory).appendingPathComponent(filename)
    try contents.write(
      to: outputPath,
      atomically: true,
      encoding: .utf8
    )

    return outputPath
  }

}
