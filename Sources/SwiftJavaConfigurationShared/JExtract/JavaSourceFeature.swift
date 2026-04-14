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

/// A feature that requires a minimum Java source level.
///
/// Use with ``Configuration/supports(_:)`` to conditionally emit
/// source-level-dependent constructs.
public struct JavaSourceFeature: Sendable {
  /// The minimum Java source level required for this feature
  public let minimumJavaSourceLevel: JavaSourceLevel

  /// Human-readable description of the feature
  public let description: String
}

extension JavaSourceFeature {
  /// JavaDoc `{@snippet}` tag support (JEP 413, JDK 18+)
  public static let javadocSnippets = JavaSourceFeature(
    minimumJavaSourceLevel: .jdk18,
    description: "JavaDoc {@snippet} tag (JEP 413)"
  )
}
