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

extension WithModifiersSyntax {
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

extension SyntaxProtocol {

  var asNominalTypeKind: NominalTypeKind {
    if isClass {
      .class
    } else if isActor {
      .actor
    } else if isStruct {
      .struct
    } else if isEnum {
      .enum
    } else {
      fatalError("Unknown nominal kind: \(self)")
    }
  }

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
    case .keyword(.private), .keyword(.fileprivate), .keyword(.internal), .keyword(.package),
        .keyword(.public), .keyword(.open):
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
    case .keyword(.open): return true
    default: return false
    }
  }
}

extension WithModifiersSyntax {
  var isPublic: Bool {
    self.modifiers.contains { modifier in
      modifier.isPublic
    }
  }
}

extension AttributeListSyntax.Element {
  /// Whether this node has `JavaKit` attributes.
  var isJava: Bool {
    guard case let .attribute(attr) = self else {
      // FIXME: Handle #if.
      return false
    }
    let attrName = attr.attributeName.description
    switch attrName {
    case "JavaClass", "JavaInterface", "JavaField", "JavaStaticField", "JavaMethod", "JavaStaticMethod", "JavaImplementation":
      return true
    default:
      return false
    }
  }
}

extension DeclSyntaxProtocol {
  /// Find inner most "decl" node in ancestors.
  var ancestorDecl: DeclSyntax? {
    var node: Syntax = Syntax(self)
    while let parent = node.parent {
      if let decl = parent.as(DeclSyntax.self) {
        return decl
      }
      node = parent
    }
    return nil
  }

  /// Declaration name primarily for debugging.
  var nameForDebug: String {
    return switch DeclSyntax(self).as(DeclSyntaxEnum.self) {
    case .accessorDecl(let node):
      node.accessorSpecifier.text
    case .actorDecl(let node):
      node.name.text
    case .associatedTypeDecl(let node):
      node.name.text
    case .classDecl(let node):
      node.name.text
    case .deinitializerDecl(_):
      "deinit"
    case .editorPlaceholderDecl:
      ""
    case .enumCaseDecl(let node):
      // FIXME: Handle multiple elements.
      if let element = node.elements.first {
        element.name.text
      } else {
        "case"
      }
    case .enumDecl(let node):
      node.name.text
    case .extensionDecl(let node):
      node.extendedType.description
    case .functionDecl(let node):
      node.name.text + "(" + node.signature.parameterClause.parameters.map({ $0.firstName.text + ":" }).joined()  + ")"
    case .ifConfigDecl(_):
      "#if"
    case .importDecl(_):
      "import"
    case .initializerDecl(let node):
      "init" + "(" + node.signature.parameterClause.parameters.map({ $0.firstName.text + ":" }).joined()  + ")"
    case .macroDecl(let node):
      node.name.text
    case .macroExpansionDecl(let node):
      "#" + node.macroName.trimmedDescription
    case .missingDecl(_):
      "(missing)"
    case .operatorDecl(let node):
      node.name.text
    case .poundSourceLocation(_):
      "#sourceLocation"
    case .precedenceGroupDecl(let node):
      node.name.text
    case .protocolDecl(let node):
      node.name.text
    case .structDecl(let node):
      node.name.text
    case .subscriptDecl(let node):
      "subscript" + "(" + node.parameterClause.parameters.map({ $0.firstName.text + ":" }).joined()  + ")"
    case .typeAliasDecl(let node):
      node.name.text
    case .variableDecl(let node):
      // FIXME: Handle multiple variables.
      if let element = node.bindings.first {
        element.pattern.trimmedDescription
      } else {
        "var"
      }
    }
  }

  /// Qualified declaration name primarily for debugging.
  var qualifiedNameForDebug: String {
    if let parent = ancestorDecl {
      parent.qualifiedNameForDebug + "." + nameForDebug
    } else {
      nameForDebug
    }
  }

  /// Signature part of the declaration. I.e. without body or member block.
  var signatureString: String {
    return switch DeclSyntax(self.detached).as(DeclSyntaxEnum.self) {
    case .functionDecl(let node):
      node.with(\.body, nil).trimmedDescription
    case .initializerDecl(let node):
      node.with(\.body, nil).trimmedDescription
    case .classDecl(let node):
      node.with(\.memberBlock, "").trimmedDescription
    case .structDecl(let node):
      node.with(\.memberBlock, "").trimmedDescription
    case .protocolDecl(let node):
      node.with(\.memberBlock, "").trimmedDescription
    case .accessorDecl(let node):
      node.with(\.body, nil).trimmedDescription
    case .variableDecl(let node):
      node
        .with(\.bindings, PatternBindingListSyntax(
          node.bindings.map {
            $0.detached
            .with(\.accessorBlock, nil)
            .with(\.initializer, nil)
          }
        ))
        .trimmedDescription
    default:
      fatalError("unimplemented \(self.kind)")
    }
  }
}
