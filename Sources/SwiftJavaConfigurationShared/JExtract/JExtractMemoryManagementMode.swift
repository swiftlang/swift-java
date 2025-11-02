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

/// Configures how memory should be managed by the user
public enum JExtractMemoryManagementMode: String, Codable {
  /// Force users to provide an explicit `SwiftArena` to all calls that require them.
  case explicit

  /// Provide both explicit `SwiftArena` support
  /// and a default global automatic `SwiftArena` that will deallocate memory when the GC decides to.
  case allowGlobalAutomatic

  public static var `default`: Self {
    .explicit
  }

  public var requiresGlobalArena: Bool {
    switch self {
    case .explicit: false
    case .allowGlobalAutomatic: true
    }
  }
}
