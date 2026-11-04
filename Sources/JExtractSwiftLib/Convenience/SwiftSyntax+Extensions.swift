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

import SwiftSyntax

extension DeclSyntaxProtocol {
  /// Signature part of the declaration. I.e. without body or member block.
  package var signatureString: String {
    switch DeclSyntax(self.detached).as(DeclSyntaxEnum.self) {
    case .functionDecl(let node):
      node.with(\.body, nil).triviaSanitizedDescription
    case .initializerDecl(let node):
      node.with(\.body, nil).triviaSanitizedDescription
    case .classDecl(let node):
      node.with(\.memberBlock, "").triviaSanitizedDescription
    case .structDecl(let node):
      node.with(\.memberBlock, "").triviaSanitizedDescription
    case .protocolDecl(let node):
      node.with(\.memberBlock, "").triviaSanitizedDescription
    case .accessorDecl(let node):
      node.with(\.body, nil).triviaSanitizedDescription
    case .subscriptDecl(let node):
      node.with(\.accessorBlock, nil).triviaSanitizedDescription
    case .variableDecl(let node):
      node
        .with(
          \.bindings,
          PatternBindingListSyntax(
            node.bindings.map {
              $0.detached
                .with(\.accessorBlock, nil)
                .with(\.initializer, nil)
            }
          ),
        )
        .triviaSanitizedDescription
    case .enumCaseDecl(let node):
      node.triviaSanitizedDescription
    default:
      fatalError("unimplemented \(self.kind)")
    }
  }


  /// Syntax text but without unnecessary trivia.
  ///
  /// Connective trivia are condensed into a single whitespace, but no space
  /// after opening or before closing parentheses
  var triviaSanitizedDescription: String {
    let visitor = TriviaSanitizingDescriptionVisitor(viewMode: .sourceAccurate)
    visitor.walk(self.trimmed)
    return visitor.result
  }
}

class TriviaSanitizingDescriptionVisitor: SyntaxVisitor {
  var result: String = ""

  var prevTokenKind: TokenKind = .endOfFile
  var prevHadTrailingSpace: Bool = false

  override func visit(_ node: TokenSyntax) -> SyntaxVisitorContinueKind {
    let tokenKind = node.tokenKind
    switch (prevTokenKind, tokenKind) {
    case // No whitespace after open parentheses.
    (.leftAngle, _), (.leftParen, _), (.leftSquare, _), (.endOfFile, _),
      // No whitespace before close parentheses.
      (_, .rightAngle), (_, .rightParen), (_, .rightSquare):
      break
    default:
      if prevHadTrailingSpace || !node.leadingTrivia.isEmpty {
        result += " "
      }
    }
    result += node.text
    prevTokenKind = tokenKind
    prevHadTrailingSpace = !node.trailingTrivia.isEmpty

    return .skipChildren
  }
}
