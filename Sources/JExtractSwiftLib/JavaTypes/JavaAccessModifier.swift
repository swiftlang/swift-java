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

import SwiftSyntax

enum JavaAccessModifier: String, CustomStringConvertible {
  case `public`
  case `private`
  case `protected`

  var description: String {
    rawValue
  }
}

extension JavaAccessModifier {
  init?(_ syntax: some DeclSyntaxProtocol) {
    guard let syntax = syntax.asProtocol(WithModifiersSyntax.self) else {
      self = .private
      return nil
    }
    for modifier in syntax.modifiers {
      switch modifier.name.tokenKind {
      case .keyword(.private), .keyword(.fileprivate), .keyword(.internal):
        self = .private
        return
      case .keyword(.package), .keyword(.public), .keyword(.open):
        self = .public
        return
      default: break
      }
    }
    if syntax.is(EnumCaseDeclSyntax.self) {
      self = .public
      return
    }
    return nil
  }
}
