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

/// Which declarations jextract exports to Java.
public enum JExtractExportMode: String, Codable {
  /// Export every declaration that passes the access level and filters, except those marked
  /// `@JavaExport(false)` or inside a type or extension marked `@JavaExport(false)`.
  case all

  /// Export only declarations marked `@JavaExport`, or inside a type or extension marked `@JavaExport`.
  /// A type that isn't marked is still exported when one of its members is.
  case annotated

  public static var `default`: Self {
    .all
  }
}
