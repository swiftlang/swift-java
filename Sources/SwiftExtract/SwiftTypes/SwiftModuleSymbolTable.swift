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
import SwiftSyntaxBuilder

public struct SwiftModuleSymbolTable: SwiftSymbolTableProtocol {
  /// The name of this module.
  public let moduleName: String

  /// The name of module required to be imported and checked via canImport statement.
  public let requiredAvailablityOfModuleWithName: String?

  /// Data about alternative modules which provides desired symbos e.g. FoundationEssentials is non-Darwin platform alternative for Foundation
  public let alternativeModules: AlternativeModuleNamesData?

  /// The top-level nominal types, found by name.
  public var topLevelTypes: [String: SwiftNominalTypeDeclaration] = [:]

  /// The top-level typealias declarations, found by name.
  public var topLevelTypeAliases: [String: SwiftTypeAliasDeclaration] = [:]

  /// The nested types defined within this module. The map itself is indexed by the
  /// identifier of the nominal type declaration, and each entry is a map from the nested
  /// type name to the nominal type declaration.
  public var nestedTypes: [SwiftNominalTypeDeclaration: [String: SwiftNominalTypeDeclaration]] = [:]

  /// The nested typealias declarations defined within this module. The map itself is indexed
  /// by the nominal type declaration, and each entry is a map from the nested typealias
  /// name to the typealias declaration.
  public var nestedTypeAliases: [SwiftNominalTypeDeclaration: [String: SwiftTypeAliasDeclaration]] = [:]

  /// Look for a top-level type with the given name.
  public func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration? {
    topLevelTypes[name]
  }

  /// Look for a top-level typealias with the given name.
  public func lookupTopLevelTypealias(_ name: String) -> SwiftTypeAliasDeclaration? {
    topLevelTypeAliases[name]
  }

  // Look for a nested type with the given name.
  public func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration? {
    nestedTypes[parent]?[name]
  }

  // Look for a nested typealias with the given name.
  public func lookupNestedTypealias(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftTypeAliasDeclaration? {
    nestedTypeAliases[parent]?[name]
  }

  public func isAlternative(for moduleName: String) -> Bool {
    alternativeModules.flatMap { $0.moduleNames.contains(moduleName) } ?? false
  }
}

extension SwiftModuleSymbolTable {
  public struct AlternativeModuleNamesData {
    /// Flag indicating module should be used as source of symbols to avoid duplication of symbols.
    public let isMainSourceOfSymbols: Bool

    /// Names of modules which are alternative for currently checked module.
    public let moduleNames: Set<String>
  }
}
