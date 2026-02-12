//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftSyntax

enum TranslatedDocumentation {
  static func printDocumentation(
    importedFunc: ImportedFunc,
    translatedDecl: FFMSwift2JavaGenerator.TranslatedFunctionDecl,
    in printer: inout CodePrinter
  ) {
    var documentation = SwiftDocumentationParser.parse(importedFunc.swiftDecl)

    if translatedDecl.translatedSignature.requiresSwiftArena {
      documentation?.parameters.append(
        SwiftDocumentation.Parameter(
          name: "swiftArena$",
          description: "the arena that will manage the lifetime and allocation of Swift objects"
        )
      )
    }

    printDocumentation(documentation, syntax: importedFunc.swiftDecl, in: &printer)
  }

  static func printDocumentation(
    importedFunc: ImportedFunc,
    translatedDecl: JNISwift2JavaGenerator.TranslatedFunctionDecl,
    in printer: inout CodePrinter
  ) {
    var documentation = SwiftDocumentationParser.parse(importedFunc.swiftDecl)

    if translatedDecl.translatedFunctionSignature.requiresSwiftArena {
      documentation?.parameters.append(
        SwiftDocumentation.Parameter(
          name: "swiftArena$",
          description: "the arena that the the returned object will be attached to"
        )
      )
    }

    printDocumentation(documentation, syntax: importedFunc.swiftDecl, in: &printer)
  }

  private static func printDocumentation(
    _ parsedDocumentation: SwiftDocumentation?,
    syntax: some DeclSyntaxProtocol,
    in printer: inout CodePrinter
  ) {
    var groups = [String]()
    if let summary = parsedDocumentation?.summary {
      groups.append("\(summary)")
    }

    if let discussion = parsedDocumentation?.discussion {
      let paragraphs = discussion.split(separator: "\n\n")
      for paragraph in paragraphs {
        groups.append("<p>\(paragraph)")
      }
    }

    groups.append(
      """
      \(parsedDocumentation != nil ? "<p>" : "")Downcall to Swift:
      {@snippet lang=swift :
      \(syntax.signatureString)
      }
      """
    )

    var annotationsGroup = [String]()

    for param in parsedDocumentation?.parameters ?? [] {
      annotationsGroup.append("@param \(param.name) \(param.description)")
    }

    if let returns = parsedDocumentation?.returns {
      annotationsGroup.append("@return \(returns)")
    }

    if !annotationsGroup.isEmpty {
      groups.append(annotationsGroup.joined(separator: "\n"))
    }

    printer.print("/**")
    let oldIdentationText = printer.indentationText
    printer.indentationText += " * "
    for (idx, group) in groups.enumerated() {
      printer.print(group)
      if idx < groups.count - 1 {
        printer.print("")
      }
    }
    printer.indentationText = oldIdentationText
    printer.print(" */")

  }
}
