//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Minimum access level a declaration must have to be considered for extraction.
///
/// Lives in the small `SwiftExtractConfigurationShared` target so the analysis
/// layer and language-specific configuration layers (e.g. swift-java's
/// `SwiftJavaConfigurationShared`) can both depend on it without dragging
/// SwiftSyntax into the latter.
#if compiler(>=6.2)
@nonexhaustive
#endif
public enum AccessLevelMode: String, Codable, Sendable {
  case `public`
  case `package`
  case `internal`
}

extension AccessLevelMode {
  public static var `default`: Self {
    .public
  }
}
