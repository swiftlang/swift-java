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

struct SwiftModuleSymbolTable: SwiftSymbolTableProtocol {
  /// The name of this module.
  let moduleName: String

  /// The top-level nominal types, found by name.
  var topLevelTypes: [String: SwiftNominalTypeDeclaration] = [:]

  /// The nested types defined within this module. The map itself is indexed by the
  /// identifier of the nominal type declaration, and each entry is a map from the nested
  /// type name to the nominal type declaration.
  var nestedTypes: [SwiftNominalTypeDeclaration: [String: SwiftNominalTypeDeclaration]] = [:]

  /// Look for a top-level type with the given name.
  func lookupTopLevelNominalType(_ name: String) -> SwiftNominalTypeDeclaration? {
    topLevelTypes[name]
  }

  // Look for a nested type with the given name.
  func lookupNestedType(_ name: String, parent: SwiftNominalTypeDeclaration) -> SwiftNominalTypeDeclaration? {
    nestedTypes[parent]?[name]
  }
}
