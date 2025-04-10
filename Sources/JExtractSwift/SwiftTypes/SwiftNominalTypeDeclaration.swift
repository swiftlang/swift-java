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

/// Describes a nominal type declaration, which can be of any kind (class, struct, etc.)
/// and has a name, parent type (if nested), and owning module.
class SwiftNominalTypeDeclaration {
  enum Kind {
    case actor
    case `class`
    case `enum`
    case `protocol`
    case `struct`
  }

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
  lazy var knownStandardLibraryType: KnownStandardLibraryType? = {
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
  private func computeKnownStandardLibraryType() -> KnownStandardLibraryType? {
    if parent != nil || moduleName != "Swift" {
      return nil
    }

    return KnownStandardLibraryType(typeNameInSwiftModule: name)
  }
}

extension SwiftNominalTypeDeclaration: Equatable {
  static func ==(lhs: SwiftNominalTypeDeclaration, rhs: SwiftNominalTypeDeclaration) -> Bool {
    lhs === rhs
  }
}

extension SwiftNominalTypeDeclaration: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
