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

import SwiftDiagnostics
import SwiftSyntax

extension DeclGroupSyntax {
  internal var accessControlModifiers: DeclModifierListSyntax {
    modifiers.filter { modifier in
      modifier.isAccessControl
    }
  }
}

extension FunctionDeclSyntax {
  internal var accessControlModifiers: DeclModifierListSyntax {
    modifiers.filter { modifier in
      modifier.isAccessControl
    }
  }
}

extension VariableDeclSyntax {
  internal var accessControlModifiers: DeclModifierListSyntax {
    modifiers.filter { modifier in
      modifier.isAccessControl
    }
  }
}

extension ImplicitlyUnwrappedOptionalTypeSyntax {
  internal var asOptionalTypeSyntax: any TypeSyntaxProtocol {
    OptionalTypeSyntax(
      leadingTrivia: leadingTrivia,
      unexpectedBeforeWrappedType,
      wrappedType: wrappedType,
      self.unexpectedBetweenWrappedTypeAndExclamationMark,
      self.unexpectedAfterExclamationMark,
      trailingTrivia: self.trailingTrivia
    )
  }
}

extension TypeSyntax {
  fileprivate var isActorSystem: Bool {
    self.trimmedDescription == "ActorSystem"
  }
}

extension DeclSyntaxProtocol {
  var isClass: Bool {
    return self.is(ClassDeclSyntax.self)
  }

  var isActor: Bool {
    return self.is(ActorDeclSyntax.self)
  }

  var isEnum: Bool {
    return self.is(EnumDeclSyntax.self)
  }

  var isStruct: Bool {
    return self.is(StructDeclSyntax.self)
  }
}

extension DeclModifierSyntax {
  var isAccessControl: Bool {
    switch self.name.tokenKind {
    case .keyword(.private): fallthrough
    case .keyword(.fileprivate): fallthrough
    case .keyword(.internal): fallthrough
    case .keyword(.package): fallthrough
    case .keyword(.public):
      return true
    default:
      return false
    }
  }
}

extension DeclModifierSyntax {
  var isPublic: Bool {
    switch self.name.tokenKind {
    case .keyword(.private): return false
    case .keyword(.fileprivate): return false
    case .keyword(.internal): return false
    case .keyword(.package): return false
    case .keyword(.public): return true
    default: return false
    }
  }
}
