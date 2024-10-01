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

/// Perform nominal type resolution, including the binding of extensions to
/// their extended nominal types and mapping type names to their full names.
@_spi(Testing)
public class NominalTypeResolution {
  /// Mapping from the syntax identifier for a given type declaration node,
  /// such as StructDeclSyntax, to the set of extensions of this particular
  /// type.
  private var extensionsByType: [SyntaxIdentifier: [ExtensionDeclSyntax]] = [:]

  /// Mapping from extension declarations to the type declaration that they
  /// extend.
  private var resolvedExtensions: [ExtensionDeclSyntax: NominalTypeDeclSyntaxNode] = [:]

  /// Extensions that have been encountered but not yet resolved to
  private var unresolvedExtensions: [ExtensionDeclSyntax] = []

  /// Mapping from qualified nominal type names to their syntax nodes.
  private var topLevelNominalTypes: [String: NominalTypeDeclSyntaxNode] = [:]

  @_spi(Testing) public init() { }
}

/// A syntax node for a nominal type declaration.
@_spi(Testing)
public typealias NominalTypeDeclSyntaxNode = any DeclGroupSyntax & NamedDeclSyntax

// MARK: Nominal type name resolution.
extension NominalTypeResolution {
  /// Compute the fully-qualified name of the given nominal type node.
  ///
  /// This produces the name that can be resolved back to the nominal type
  /// via resolveNominalType(_:).
  @_spi(Testing)
  public func fullyQualifiedName(of node: NominalTypeDeclSyntaxNode) -> String? {
    let nameComponents = fullyQualifiedNameComponents(of: node)
    return nameComponents.isEmpty ? nil : nameComponents.joined(separator: ".")
  }

  private func fullyQualifiedNameComponents(of node: NominalTypeDeclSyntaxNode) -> [String] {
    var nameComponents: [String] = []

    var currentNode = Syntax(node)
    while true {
      // If it's a nominal type, add its name.
      if let nominal = currentNode.asProtocol(SyntaxProtocol.self) as? NominalTypeDeclSyntaxNode,
         let nominalName = nominal.name.identifier?.name {
        nameComponents.append(nominalName)
      }

      // If it's an extension, add the full name of the extended type.
      if let extensionDecl = currentNode.as(ExtensionDeclSyntax.self),
         let extendedNominal = extendedType(of: extensionDecl) {
        let extendedNominalNameComponents = fullyQualifiedNameComponents(of: extendedNominal)
        return extendedNominalNameComponents + nameComponents.reversed()
      }

      guard let parent = currentNode.parent else {
        break

      }
      currentNode = parent
    }

    return nameComponents.reversed()
  }

  /// Resolve a nominal type name to its syntax node, or nil if it cannot be
  /// resolved for any reason.
  @_spi(Testing)
  public func resolveNominalType(_ name: String) -> NominalTypeDeclSyntaxNode? {
    let components = name.split(separator: ".")
    return resolveNominalType(components)
  }

  /// Resolve a nominal type name to its syntax node, or nil if it cannot be
  /// resolved for any reason.
  private func resolveNominalType(_ nameComponents: some Sequence<some StringProtocol>) -> NominalTypeDeclSyntaxNode? {
    // Resolve the name components in order.
    var currentNode: NominalTypeDeclSyntaxNode? = nil
    for nameComponentStr in nameComponents {
      let nameComponent = String(nameComponentStr)

      var nextNode: NominalTypeDeclSyntaxNode? = nil
      if let currentNode {
        nextNode = lookupNominalType(nameComponent, in: currentNode)
      } else {
        nextNode = topLevelNominalTypes[nameComponent]
      }

      // If we couldn't resolve the next name, we're done.
      guard let nextNode else {
        return nil
      }

      currentNode = nextNode
    }

    return currentNode
  }

  /// Look for a nominal type with the given name within this declaration group,
  /// which could be a nominal type declaration or extension thereof.
  private func lookupNominalType(
    _ name: String,
    inDeclGroup parentNode: some DeclGroupSyntax
  ) -> NominalTypeDeclSyntaxNode? {
    for member in parentNode.memberBlock.members {
      let memberDecl = member.decl.asProtocol(DeclSyntaxProtocol.self)

      // If we have a member with the given name that is a nominal type
      // declaration, we found what we're looking for.
      if let namedMemberDecl = memberDecl.asProtocol(NamedDeclSyntax.self),
         namedMemberDecl.name.identifier?.name == name,
         let nominalTypeDecl = memberDecl as? NominalTypeDeclSyntaxNode
      {
        return nominalTypeDecl
      }
    }

    return nil
  }

  /// Lookup nominal type name within a given nominal type.
  private func lookupNominalType(
    _ name: String,
    in parentNode: NominalTypeDeclSyntaxNode
  ) -> NominalTypeDeclSyntaxNode? {
    // Look in the parent node itself.
    if let found = lookupNominalType(name, inDeclGroup: parentNode) {
      return found
    }

    // Look in known extensions of the parent node.
    if let extensions = extensionsByType[parentNode.id] {
      for extensionDecl in extensions {
        if let found = lookupNominalType(name, inDeclGroup: extensionDecl) {
          return found
        }
      }
    }

    return nil
  }
}

// MARK: Binding extensions
extension NominalTypeResolution {
  /// Look up the nominal type declaration to which this extension is bound.
  @_spi(Testing)
  public func extendedType(of extensionDecl: ExtensionDeclSyntax) -> NominalTypeDeclSyntaxNode? {
    return resolvedExtensions[extensionDecl]
  }

  /// Bind all of the unresolved extensions to their nominal types.
  ///
  /// Returns the list of extensions that could not be resolved.
  @_spi(Testing)
  @discardableResult
  public func bindExtensions() -> [ExtensionDeclSyntax] {
    while !unresolvedExtensions.isEmpty {
      // Try to resolve all of the unresolved extensions.
      let numExtensionsBefore = unresolvedExtensions.count
      unresolvedExtensions.removeAll { extensionDecl in
        // Try to resolve the type referenced by this extension declaration. If
        // it fails, we'll try again later.
        let nestedTypeNameComponents = extensionDecl.nestedTypeName
        guard let resolvedType = resolveNominalType(nestedTypeNameComponents) else {
          return false
        }

        // We have successfully resolved the extended type. Record it and
        // remove the extension from the list of unresolved extensions.
        extensionsByType[resolvedType.id, default: []].append(extensionDecl)
        resolvedExtensions[extensionDecl] = resolvedType

        return true
      }

      // If we didn't resolve anything, we're done.
      if numExtensionsBefore == unresolvedExtensions.count {
        break
      }

      assert(numExtensionsBefore > unresolvedExtensions.count)
    }

    // Any unresolved extensions at this point are fundamentally unresolvable.
    return unresolvedExtensions
  }
}

extension ExtensionDeclSyntax {
  /// Produce the nested type name for the given decl
  fileprivate var nestedTypeName: [String] {
    var nameComponents: [String] = []
    var extendedType = extendedType
    while true {
      switch extendedType.as(TypeSyntaxEnum.self) {
      case .attributedType(let attributedType):
        extendedType = attributedType.baseType
        continue

      case .identifierType(let identifierType):
        guard let identifier = identifierType.name.identifier else {
          return []
        }

        nameComponents.append(identifier.name)
        return nameComponents.reversed()

      case .memberType(let memberType):
        guard let identifier = memberType.name.identifier else {
          return []
        }

        nameComponents.append(identifier.name)
        extendedType = memberType.baseType
        continue

      // Structural types implemented as nominal types.
      case .arrayType:
        return ["Array"]

      case .dictionaryType:
        return ["Dictionary"]

      case .implicitlyUnwrappedOptionalType, .optionalType:
        return [ "Optional" ]

      // Types that never involve nominals.

      case .classRestrictionType, .compositionType, .functionType, .metatypeType,
          .missingType, .namedOpaqueReturnType, .packElementType,
          .packExpansionType, .someOrAnyType, .suppressedType, .tupleType:
        return []
      }
    }
  }
}

// MARK: Adding source files to the resolution.
extension NominalTypeResolution {
  /// Add the given source file.
  @_spi(Testing)
  public func addSourceFile(_ sourceFile: SourceFileSyntax) {
    let visitor = NominalAndExtensionFinder(typeResolution: self)
    visitor.walk(sourceFile)
  }

  private class NominalAndExtensionFinder: SyntaxVisitor {
    var typeResolution: NominalTypeResolution
    var nestingDepth = 0

    init(typeResolution: NominalTypeResolution) {
      self.typeResolution = typeResolution
      super.init(viewMode: .sourceAccurate)
    }

    // Entering nominal type declarations.

    func visitNominal(_ node: NominalTypeDeclSyntaxNode) {
      if nestingDepth == 0 {
        typeResolution.topLevelNominalTypes[node.name.text] = node
      }

      nestingDepth += 1
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
      visitNominal(node)
      return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
      visitNominal(node)
      return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
      visitNominal(node)
      return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
      visitNominal(node)
      return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
      visitNominal(node)
      return .visitChildren
    }

    // Exiting nominal type declarations.
    func visitPostNominal(_ node: NominalTypeDeclSyntaxNode) {
      assert(nestingDepth > 0)
      nestingDepth -= 1
    }

    override func visitPost(_ node: ActorDeclSyntax) {
      visitPostNominal(node)
    }

    override func visitPost(_ node: ClassDeclSyntax) {
      visitPostNominal(node)
    }

    override func visitPost(_ node: EnumDeclSyntax) {
      visitPostNominal(node)
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
      visitPostNominal(node)
    }

    override func visitPost(_ node: StructDeclSyntax) {
      visitPostNominal(node)
    }

    // Extension handling
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
      // Note that the extension is unresolved. We'll bind it later.
      typeResolution.unresolvedExtensions.append(node)
      nestingDepth += 1
      return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
      nestingDepth -= 1
    }

    // Avoid stepping into functions.

    override func visit(_ node: CodeBlockSyntax) -> SyntaxVisitorContinueKind {
      return .skipChildren
    }
  }
}
