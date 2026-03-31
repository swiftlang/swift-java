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
import SwiftSyntaxMacros

/// Marker macro for jextract: forces a Swift declaration to be exported to Java.
///
/// When applied to a typealias, registers a monomorphization entry for generic types.
/// When applied to a nominal type, force-includes it for export regardless of filters.
///
/// This macro produces no code — it is purely a marker read by the jextract tool.
package enum JavaExportMacro {}

extension JavaExportMacro: PeerMacro {
  package static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext,
  ) throws -> [DeclSyntax] {
    // Marker-only macro — no code generation
    []
  }
}
