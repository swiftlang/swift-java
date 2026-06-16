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

import SwiftParser
import SwiftSyntax

// ==== -----------------------------------------------------------------------
// MARK: SwiftSyntheticTypes
//
// `SwiftType` is normally only constructable from a real source declaration
// the symbol table can resolve. A few callers — primarily downstream language
// code generators that treat unresolved names symbolically (see
// `SwiftNominalTypeDeclaration.isUnresolvedTypePlaceholder` for the
// lazy-specialization motivation) — need to build an unresolved nominal
// reference from a bare type name. This builds one by parsing a throwaway
// `struct <name> {}` to obtain the syntax node the
// `SwiftNominalTypeDeclaration` initializer requires.

public enum SwiftSyntheticTypes {
  /// Build an unresolved nominal `SwiftType` for the given simple type name.
  /// The result has `isUnresolvedTypePlaceholder == true` so a downstream pass
  /// can recognize and substitute it. See
  /// `SwiftNominalTypeDeclaration.isUnresolvedTypePlaceholder` for usage.
  public static func unresolvedNominal(
    _ name: String
  ) -> SwiftType {
    let source = Parser.parse(source: "struct \(name) {}")
    // Fall back gracefully if `name` isn't a simple identifier (the parsed
    // declaration list will be empty; reuse a placeholder syntax node and
    // record the requested name on the declaration itself).
    let structSyntax: StructDeclSyntax
    if let s = source.statements.first?.item.as(StructDeclSyntax.self) {
      structSyntax = s
    } else {
      structSyntax = Parser.parse(source: "struct __Synthesized {}")
        .statements.first!.item.cast(StructDeclSyntax.self)
    }
    let decl = SwiftNominalTypeDeclaration(
      name: name,
      sourceFilePath: "",
      moduleName: "",
      parent: nil,
      node: structSyntax,
      isUnresolvedTypePlaceholder: true
    )
    return .nominal(SwiftNominalType(nominalTypeDecl: decl))
  }
}
