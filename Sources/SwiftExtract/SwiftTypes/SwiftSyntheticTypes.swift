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
// code generators that treat unresolved names symbolically (associated types,
// pre-substitution generic parameters, externally-bridged types) — need to
// build an unresolved nominal reference from a bare type name. This builds one
// by parsing a throwaway `struct <name> {}` to obtain the syntax node the
// `SwiftNominalTypeDeclaration` initializer requires.

public enum SwiftSyntheticTypes {
  /// A synthetic module name used for nominals minted by
  /// `unresolvedNominal(_:)`. Placed in the type's `moduleName` so downstream
  /// code can recognize and route around them when needed.
  public static let syntheticModuleName = "__SwiftExtractSynthesized"

  /// Build an unresolved nominal `SwiftType` for the given simple type name.
  ///
  /// Useful when the caller is willing to treat a name as a placeholder to be
  /// substituted (or recognized symbolically) by a later pass — e.g. an
  /// associated type referenced before carrier substitution, or a generic
  /// parameter referenced before specialization.
  public static func unresolvedNominal(
    _ name: String,
    moduleName: String = SwiftSyntheticTypes.syntheticModuleName
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
      moduleName: moduleName,
      parent: nil,
      node: structSyntax
    )
    return .nominal(SwiftNominalType(nominalTypeDecl: decl))
  }
}
