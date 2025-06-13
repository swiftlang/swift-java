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

///// A syntax node for a nominal type declaration.
@_spi(Testing)
public typealias NominalTypeDeclSyntaxNode = any DeclGroupSyntax & NamedDeclSyntax & WithAttributesSyntax & WithModifiersSyntax

/// Describes a nominal type declaration, which can be of any kind (class, struct, etc.)
/// and has a name, parent type (if nested), and owning module.
package class SwiftNominalTypeDeclaration {
  enum Kind {
    case actor
    case `class`
    case `enum`
    case `protocol`
    case `struct`
  }

  /// The syntax node this declaration is derived from.
  /// Can be `nil` if this is loaded from a .swiftmodule.
  var syntax: NominalTypeDeclSyntaxNode?

  /// The kind of nominal type.
  var kind: Kind

  /// The parent nominal type when this nominal type is nested inside another type, e.g.,
  /// MyCollection.Iterator.
  var parent: SwiftNominalTypeDeclaration?

  /// The module in which this nominal type is defined. If this is a nested type, the
  /// module might be different from that of the parent type, if this nominal type
  /// is defined in an extension within another module.
  var moduleName: String

  /// The name of this nominal type, e.g., 'MyCollection'.
  var name: String

  // TODO: Generic parameters.

  /// Identify this nominal declaration as one of the known standard library
  /// types, like 'Swift.Int[.
  lazy var knownStandardLibraryType: SwiftStandardLibraryTypeKind? = {
    self.computeKnownStandardLibraryType()
  }()

  /// Create a nominal type declaration from the syntax node for a nominal type
  /// declaration.
  init(
    moduleName: String,
    parent: SwiftNominalTypeDeclaration?,
    node: NominalTypeDeclSyntaxNode
  ) {
    self.moduleName = moduleName
    self.parent = parent
    self.name = node.name.text

    // Determine the kind from the syntax node.
    switch Syntax(node).as(SyntaxEnum.self) {
    case .actorDecl: self.kind = .actor
    case .classDecl: self.kind = .class
    case .enumDecl: self.kind = .enum
    case .protocolDecl: self.kind = .protocol
    case .structDecl: self.kind = .struct
    default: fatalError("Not a nominal type declaration")
    }
  }

  /// Determine the known standard library type for this nominal type
  /// declaration.
  private func computeKnownStandardLibraryType() -> SwiftStandardLibraryTypeKind? {
    if parent != nil || moduleName != "Swift" {
      return nil
    }

    return SwiftStandardLibraryTypeKind(typeNameInSwiftModule: name)
  }

  package var qualifiedName: String {
    if let parent = self.parent {
      return parent.qualifiedName + "." + name
    } else {
      return name
    }
  }

  var isReferenceType: Bool {
    switch kind {
    case .actor, .class:
      return true
    case .enum, .struct, .protocol:
      return false
    }
  }
}

extension SwiftNominalTypeDeclaration: Equatable {
  package static func ==(lhs: SwiftNominalTypeDeclaration, rhs: SwiftNominalTypeDeclaration) -> Bool {
    lhs === rhs
  }
}

extension SwiftNominalTypeDeclaration: Hashable {
  package func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
