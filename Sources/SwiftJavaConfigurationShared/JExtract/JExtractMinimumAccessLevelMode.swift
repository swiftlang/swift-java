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

/// The minimum access level which
public enum JExtractMinimumAccessLevelMode: String, Codable {
  case `public`
  case `package`
  case `internal`
}

extension JExtractMinimumAccessLevelMode {
  public static var `default`: Self {
    .public
  }
}
