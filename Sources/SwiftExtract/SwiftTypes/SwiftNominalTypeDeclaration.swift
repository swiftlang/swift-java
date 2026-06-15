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
public typealias NominalTypeDeclSyntaxNode = any DeclGroupSyntax & NamedDeclSyntax & WithAttributesSyntax
  & WithModifiersSyntax

public class SwiftTypeDeclaration {

  // The short path from module root to the file in which this nominal was originally declared.
  // E.g. for `Sources/Example/My/Types.swift` it would be `My/Types.swift`.
  public let sourceFilePath: String

  /// The module in which this nominal type is defined. If this is a nested type, the
  /// module might be different from that of the parent type, if this nominal type
  /// is defined in an extension within another module.
  public let moduleName: String

  /// The name of this nominal type, e.g. 'MyCollection'.
  public let name: String

  public init(sourceFilePath: String, moduleName: String, name: String) {
    self.sourceFilePath = sourceFilePath
    self.moduleName = moduleName
    self.name = name
  }
}

/// A syntax node paired with a simple file path
public struct SwiftInputFile {
  public let syntax: SourceFileSyntax
  /// Simple file path of the file from which the syntax node was parsed.
  public let path: String
  public init(syntax: SourceFileSyntax, path: String) {
    self.syntax = syntax
    self.path = path
  }
}

/// Describes a nominal type declaration, which can be of any kind (class, struct, etc.)
/// and has a name, parent type (if nested), and owning module.
public class SwiftNominalTypeDeclaration: SwiftTypeDeclaration {
  public enum Kind {
    case actor
    case `class`
    case `enum`
    case `protocol`
    case `struct`
  }

  /// The syntax node this declaration is derived from.
  @_spi(Testing) public let syntax: NominalTypeDeclSyntaxNode

  /// The kind of nominal type.
  public let kind: Kind

  /// The parent nominal type when this nominal type is nested inside another type, e.g.,
  /// MyCollection.Iterator.
  public let parent: SwiftNominalTypeDeclaration?

  /// The generic parameters of this nominal type.
  public let genericParameters: [SwiftGenericParameterDeclaration]

  /// True when this declaration is a placeholder synthesized by
  /// `SwiftSyntheticTypes.unresolvedNominal(_:)` because the symbol table
  /// couldn't resolve the name.
  ///
  /// Exists to support **lazy specializations** — code generators that
  /// resolve names later than analysis time. Without lenient mode the
  /// analyzer would drop entire declarations the moment any unresolved name
  /// appeared in their signature; lenient mode keeps the decl and stamps the
  /// unknown name with this flag, letting a downstream substitution pass
  /// recognize and replace it.
  ///
  /// Canonical case: an associated type in a protocol requirement. For
  ///
  ///     protocol Container {
  ///       associatedtype Element
  ///       func first() -> Element
  ///     }
  ///
  /// the symbol table has no top-level `Element` when walking `first()` — it
  /// resolves later when a conforming type fixes a carrier
  /// (`MyCollection: Container where Element == Int`). Strict mode would
  /// drop `first()` from the analysis result; lenient mode keeps it with
  /// `Element` as a placeholder a later substitution pass replaces with the
  /// carrier's real type. Generic-parameter references in the body of a
  /// generic type and externally-bridged simple-name types follow the same
  /// shape.
  public let isUnresolvedTypePlaceholder: Bool

  /// Identify this nominal declaration as one of the known standard library
  /// types, like 'Swift.Int[.
  public private(set) lazy var knownTypeKind: SwiftKnownTypeDeclKind? = {
    self.computeKnownStandardLibraryType()
  }()

  /// Create a nominal type declaration from the syntax node for a nominal type
  /// declaration.
  @_spi(Testing) public init(
    name: String,
    sourceFilePath: String,
    moduleName: String,
    parent: SwiftNominalTypeDeclaration?,
    node: NominalTypeDeclSyntaxNode,
    isUnresolvedTypePlaceholder: Bool = false,
  ) {
    self.parent = parent
    self.syntax = node
    self.isUnresolvedTypePlaceholder = isUnresolvedTypePlaceholder
    self.genericParameters =
      node.asProtocol(WithGenericParametersSyntax.self)?.genericParameterClause?.parameters.map {
        SwiftGenericParameterDeclaration(sourceFilePath: sourceFilePath, moduleName: moduleName, node: $0)
      } ?? []

    // Determine the kind from the syntax node.
    switch Syntax(node).as(SyntaxEnum.self) {
    case .actorDecl: self.kind = .actor
    case .classDecl: self.kind = .class
    case .enumDecl: self.kind = .enum
    case .protocolDecl: self.kind = .protocol
    case .structDecl: self.kind = .struct
    default: fatalError("Not a nominal type declaration")
    }
    super.init(sourceFilePath: sourceFilePath, moduleName: moduleName, name: name)
  }

  public private(set) lazy var firstInheritanceType: TypeSyntax? = {
    guard let firstInheritanceType = self.syntax.inheritanceClause?.inheritedTypes.first else {
      return nil
    }

    return firstInheritanceType.type
  }()

  public var inheritanceTypes: InheritedTypeListSyntax? {
    self.syntax.inheritanceClause?.inheritedTypes
  }

  public var genericWhereClause: GenericWhereClauseSyntax? {
    self.syntax.asProtocol(WithGenericParametersSyntax.self)?.genericWhereClause
  }

  /// Returns true if this type conforms to `Sendable` and therefore is "threadsafe".
  public private(set) lazy var isSendable: Bool = {
    // Check if Sendable is in the inheritance list
    guard let inheritanceClause = self.syntax.inheritanceClause else {
      return false
    }

    for inheritedType in inheritanceClause.inheritedTypes {
      if inheritedType.type.trimmedDescription == "Sendable" {
        return true
      }
    }

    return false
  }()

  /// Determine the known standard library type for this nominal type
  /// declaration.
  private func computeKnownStandardLibraryType() -> SwiftKnownTypeDeclKind? {
    if parent != nil {
      return nil
    }

    return SwiftKnownTypeDeclKind(rawValue: "\(moduleName).\(name)")
  }

  /// Structured qualified type name built from the parent chain
  public var qualifiedTypeName: SwiftQualifiedTypeName {
    if let parent = self.parent {
      return SwiftQualifiedTypeName(parent.qualifiedTypeName.components + [name])
    } else {
      return SwiftQualifiedTypeName(name)
    }
  }

  public var qualifiedName: String {
    qualifiedTypeName.fullName
  }

  /// Like `qualifiedName` but with dots replaced by underscores, suitable for
  /// use in C symbol names and Java identifiers
  public var flatName: String {
    qualifiedTypeName.fullFlatName
  }

  public var isReferenceType: Bool {
    switch kind {
    case .actor, .class:
      return true
    case .enum, .struct, .protocol:
      return false
    }
  }

  public var isGeneric: Bool {
    !genericParameters.isEmpty
  }
}

extension SwiftNominalTypeDeclaration: CustomStringConvertible {
  public var description: String {
    if isGeneric {
      "\(qualifiedName)<\(genericParameters.map(\.name).joined(separator: ", "))>"
    } else {
      qualifiedName
    }
  }
}

public class SwiftGenericParameterDeclaration: SwiftTypeDeclaration {
  public let syntax: GenericParameterSyntax

  public init(
    sourceFilePath: String,
    moduleName: String,
    node: GenericParameterSyntax
  ) {
    self.syntax = node
    super.init(sourceFilePath: sourceFilePath, moduleName: moduleName, name: node.name.text)
  }

  public var hasEach: Bool {
    syntax.specifier?.tokenKind == .keyword(.each)
  }

  public var packReferenceName: String {
    if hasEach {
      "each \(name)"
    } else {
      name
    }
  }

  public var packExpansionName: String {
    if hasEach {
      "repeat each \(name)"
    } else {
      name
    }
  }
}

/// A plain typealias will resolve as the right hand type in generated code.
///
/// A typealias used as a specialization of a generic type will be emitted as
/// a new concrete type in the Java. This way we can specialize `FishBox` from
/// `Box<T>` by doing `typealias FishBox = Box<Fish>`.
public final class SwiftTypeAliasDeclaration: SwiftTypeDeclaration {
  public let syntax: TypeAliasDeclSyntax

  public init(
    sourceFilePath: String,
    moduleName: String,
    node: TypeAliasDeclSyntax
  ) {
    self.syntax = node
    super.init(sourceFilePath: sourceFilePath, moduleName: moduleName, name: node.name.text)
  }
}

extension SwiftTypeDeclaration: Equatable {
  public static func == (lhs: SwiftTypeDeclaration, rhs: SwiftTypeDeclaration) -> Bool {
    lhs === rhs
  }
}

extension SwiftTypeDeclaration: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(self))
  }
}
