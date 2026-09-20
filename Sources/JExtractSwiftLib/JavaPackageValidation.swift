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

/// Errors raised when `jextract` is configured without a usable Java package.
package enum JavaPackageError: Error, Equatable, CustomStringConvertible {
  /// `javaPackage` was `nil`, empty, whitespace-only, or had surrounding whitespace.
  case missing
  /// `javaPackage` contained an empty segment, e.g. `com..foo`, `.foo`, or `foo.`.
  case emptySegment(String)

  package var description: String {
    switch self {
    case .missing:
      return
        "Missing or empty Java package. jextract requires a non-empty '--java-package' (or javaPackage in swift-java.config). The unnamed/default package is not supported."
    case .emptySegment(let javaPackage):
      return "Invalid Java package '\(javaPackage)': must not contain empty segments."
    }
  }
}

/// Returns `javaPackage` unchanged when it is a non-empty, non-blank package name with no empty segments.
///
/// Surrounding whitespace is rejected rather than trimmed, so malformed configuration is not silently rewritten.
package func validateJavaPackage(_ javaPackage: String?) throws -> String {
  guard let javaPackage,
    javaPackage == javaPackage.trimmingCharacters(in: .whitespacesAndNewlines),
    !javaPackage.isEmpty
  else {
    throw JavaPackageError.missing
  }

  for component in javaPackage.split(separator: ".", omittingEmptySubsequences: false) {
    if component.isEmpty {
      throw JavaPackageError.emptySegment(javaPackage)
    }
  }

  return javaPackage
}
