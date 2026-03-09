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

/// A Swift compiler version with major, minor, and optional patch components.
struct SwiftVersion {
  var major: Int
  var minor: Int
  var patch: Int?

  /// The minimum compiler version required for `@available(Android ...)` platform availability.
  static let androidPlatformAvailability = SwiftVersion(major: 6, minor: 3)
}
