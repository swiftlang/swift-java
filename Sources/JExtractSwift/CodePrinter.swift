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

  public static func toString(_ block: (inout CodePrinter) -> ()) -> String {
    var printer = CodePrinter()
    block(&printer)
    return printer.finalize()
  }

  public init() {

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
    indent()
    print("\(text) {")
    body(&self)
    outdent()
    print("}", .sloc, function: function, file: file, line: line)
  }

  public mutating func print(
    _ text: Any,
    _ terminator: PrinterTerminator = .newLine,
    function: String = #function,
    file: String = #fileID,
    line: UInt = #line
  ) {
    append(indentationText)

    let lines = "\(text)".split(separator: "\n")
    if indentationDepth > 0 && lines.count > 1 {
      for line in lines {
        append(indentationText)
        append(contentsOf: line)
        append("\n")
      }
    } else {
      append("\(text)")
    }

    if terminator == .sloc {
      append(" // \(function) @ \(file):\(line)\n")
      append(indentationText)
    } else {
      append(terminator.rawValue)
      if terminator == .newLine || terminator == .commaNewLine {
        append(indentationText)
      }
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
