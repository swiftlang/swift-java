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

/// A pluggable extraction decision for downstream language generators
///
/// The built-in analyzer always applies its access-level filter; a supplied
/// `ExtractDecider` can override that decision on a per-decl basis to encode
/// language-specific rules. For example, the Java target uses one to honor
/// `@JavaExport` (force-include even when access-level would skip) and to
/// skip Swift wrappers of Java types (`@JavaClass`, `@JavaInterface`, …)
public protocol ExtractDecider {
  /// - Parameters:
  ///   - decl: the declaration being considered
  ///   - accessLevelPasses: whether the analyzer's built-in access-level
  ///     check admits the decl
  /// - Returns: `true` to force-extract (even when `accessLevelPasses`
  ///   is `false`), `false` to skip (even when `accessLevelPasses` is
  ///   `true`), or `nil` to defer to the default behavior
  func shouldExtract(decl: DeclSyntax, accessLevelPasses: Bool) -> Bool?
}
