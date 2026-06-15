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

import SwiftSyntax

/// Decides if a declaration should be extracted. This logic is specific for every output language and should handle things like access control as well as supported features when deciding of to import or skip a decl
///
/// `SwiftExtract` itself is language-neutral and applies no extraction
/// policy of its own beyond resolving the declaration. The decider is the
/// single place that decides, for a given decl, whether the analyzer should
/// import it. That covers the access-level filter, attribute rules
/// (e.g. Java's `@JavaExport` / `@JavaClass` family), and target-specific
/// quirks (e.g. skipping Swift operators when the language can't render
/// them). When no decider is provided, the analyzer falls back to
/// `DefaultAccessLevelExtractDecider`, which only enforces the configured
/// access level
public protocol ExtractDecider {
  /// Decide whether `decl` should be extracted.
  ///
  /// - Parameters:
  ///   - decl: the declaration being considered
  ///   - parent: the nominal type containing `decl`, when applicable
  ///   - log: the analyzer's logger; deciders should emit a `.trace` line
  ///     for each skip path so users can see why a decl was dropped
  func shouldExtract(
    decl: DeclSyntax,
    in parent: ExtractedNominalType?,
    log: Logger
  ) -> Bool
}

/// Minimal `ExtractDecider` that enforces only the configured access-level
/// filter. Used by `SwiftAnalyzer` when no decider is supplied
public struct DefaultAccessLevelExtractDecider: ExtractDecider {
  public let accessLevel: AccessLevelMode

  public init(accessLevel: AccessLevelMode) {
    self.accessLevel = accessLevel
  }

  public func shouldExtract(
    decl: DeclSyntax,
    in parent: ExtractedNominalType?,
    log: Logger
  ) -> Bool {
    guard let mod = decl.asProtocol((any WithModifiersSyntax).self) else {
      return false
    }
    let ok = mod.passesAccessLevel(accessLevel, in: parent)
    if !ok {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': not at least \(accessLevel)")
    }
    return ok
  }
}
