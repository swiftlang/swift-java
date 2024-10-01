//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Manifest describing the a Swift module containing translations of
/// Java classes into Swift types.
struct TranslationManifest: Codable {
  /// The Swift module name.
  var swiftModule: String

  /// The mapping from canonical Java class names (e.g., `java.lang.Object`) to
  /// the Swift type name (e.g., `JavaObject`) within `swiftModule`.
  var translatedClasses: [String: String] = [:]
}
