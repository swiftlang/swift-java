//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJavaConfigurationShared

// ==== -----------------------------------------------------------------------
// MARK: Swift filter pattern classification

/// A filter pattern is either a file-path pattern (uses `/`) or a type-name
/// pattern (uses `.`). Plain names with neither separator match both
enum SwiftFilterPatternKind {
  /// Pattern contains `/` or `**` — matches against relative file paths
  case filePath
  /// Pattern contains `.` — matches against qualified type names
  case typeName
  /// Plain name with no separators — matches against both
  case plain
}

func classifyPattern(_ pattern: String) -> SwiftFilterPatternKind {
  if pattern.contains("/") || pattern.contains("**") {
    return .filePath
  }
  if pattern.contains(".") {
    return .typeName
  }
  return .plain
}

// ==== -----------------------------------------------------------------------
// MARK: Glob-like matching

/// Match a value split by `separator` against a glob-like pattern split by the
/// same separator. Supports `**` (zero or more segments) and trailing `*`
/// within a segment
private func matchesGlob(
  value: String,
  pattern: String,
  separator: Character
) -> Bool {
  let valueParts = value.split(separator: separator, omittingEmptySubsequences: true)
  let patternParts = pattern.split(separator: separator, omittingEmptySubsequences: true)

  return matchParts(
    valueParts: Array(valueParts),
    valueIdx: 0,
    patternParts: Array(patternParts),
    patternIdx: 0
  )
}

/// Walk `valueParts` and `patternParts` in lockstep starting from the given
/// positions. Literal segments must match one-to-one; a `**` segment can
/// consume zero or more value segments (resolved by trying every possible
/// skip length recursively)
private func matchParts(
  valueParts: [Substring],
  valueIdx: Int,
  patternParts: [Substring],
  patternIdx: Int
) -> Bool {
  var valueIdx = valueIdx
  var patternIdx = patternIdx

  while patternIdx < patternParts.count {
    let currentPattern = patternParts[patternIdx]

    if currentPattern == "**" {
      return matchDoubleStarWildcard(
        valueParts: valueParts,
        valueIdx: valueIdx,
        patternParts: patternParts,
        doubleStarIdx: patternIdx
      )
    }

    // Pattern still has literal parts but value is exhausted — no match
    guard valueIdx < valueParts.count else {
      return false
    }

    guard matchSegment(String(valueParts[valueIdx]), against: String(currentPattern)) else {
      return false
    }
    valueIdx += 1
    patternIdx += 1
  }

  // Full match only when both sides are exhausted
  return valueIdx == valueParts.count
}

/// Handle a `**` wildcard at `doubleStarPos` in the pattern.
/// `**` matches zero or more consecutive value segments, so we try every
/// possible number of skipped segments and recurse on the remainder
private func matchDoubleStarWildcard(
  valueParts: [Substring],
  valueIdx: Int,
  patternParts: [Substring],
  doubleStarIdx: Int
) -> Bool {
  // `**` at the end of the pattern matches everything remaining
  if doubleStarIdx == patternParts.count - 1 {
    return true
  }

  // Try consuming 0, 1, 2, ... value segments with the `**`
  for skipCount in valueIdx...valueParts.count {
    if matchParts(
      valueParts: valueParts,
      valueIdx: skipCount,
      patternParts: patternParts,
      patternIdx: doubleStarIdx + 1
    ) {
      return true
    }
  }
  return false
}

/// Match a single segment against a pattern segment.
/// Supports trailing `*` wildcard (e.g. `Us*` matches `User`)
private func matchSegment(_ segment: String, against pattern: String) -> Bool {
  if pattern == "*" {
    return true
  }
  if pattern.hasSuffix("*") {
    let prefix = String(pattern.dropLast())
    return segment.hasPrefix(prefix)
  }
  return segment == pattern
}

// ==== -----------------------------------------------------------------------
// MARK: File-path matching

/// Check whether `relativePath` (including `.swift` extension, using `/` separators)
/// matches the given glob-like `pattern`.
///
/// Supported pattern syntax:
///  - `**` matches zero or more path segments
///  - `*` at the end of a segment matches any suffix (e.g. `Us*` matches `User.swift`)
///  - exact segment match otherwise
func matchesFilePathFilter(relativePath: String, pattern: String) -> Bool {
  matchesGlob(value: relativePath, pattern: pattern, separator: "/")
}

// ==== -----------------------------------------------------------------------
// MARK: Type-name matching

/// Check whether a qualified type name (e.g. `Something.Other`) matches a
/// dot-separated pattern.
///
/// Supported pattern syntax:
///  - `**` matches zero or more name components
///  - `*` at the end of a component matches any suffix
///  - exact component match otherwise
func matchesTypeNameFilter(qualifiedName: String, pattern: String) -> Bool {
  matchesGlob(value: qualifiedName, pattern: pattern, separator: ".")
}

// ==== -----------------------------------------------------------------------
// MARK: Combined filter application

/// Determine whether a file at the given `relativePath` (including `.swift`
/// extension) should be included in jextract processing, based on the
/// include/exclude filters in `config`.
///
/// Only file-path patterns (containing `/`) and plain patterns (no `/` or `.`)
/// are checked here. Type-name patterns are skipped — use `shouldJExtractType`
/// for those
func shouldJExtractFile(relativePath: String, config: Configuration) -> Bool {
  if let includeFilters = config.swiftFilterInclude, !includeFilters.isEmpty {
    // Must match at least one file-level include pattern.
    // If all include patterns are type-name patterns, don't filter at file level
    let filePatterns = includeFilters.filter { classifyPattern($0) != .typeName }
    if !filePatterns.isEmpty {
      let included = filePatterns.contains { pattern in
        matchesFilePattern(relativePath: relativePath, pattern: pattern)
      }
      guard included else {
        return false
      }
    }
  }

  if let excludeFilters = config.swiftFilterExclude, !excludeFilters.isEmpty {
    let filePatterns = excludeFilters.filter { classifyPattern($0) != .typeName }
    let excluded = filePatterns.contains { pattern in
      matchesFilePattern(relativePath: relativePath, pattern: pattern)
    }
    if excluded {
      return false
    }
  }

  return true
}

/// Match a file pattern against a relative path. Plain patterns (no `/` or `.`)
/// are matched against the filename without the `.swift` extension; file-path
/// patterns are matched against the full relative path as-is
private func matchesFilePattern(relativePath: String, pattern: String) -> Bool {
  switch classifyPattern(pattern) {
  case .plain:
    // Plain pattern like "MyType" — match against just the filename sans .swift
    let fileName = relativePath.split(separator: "/").last.map(String.init) ?? relativePath
    return matchSegment(fileName.dropSwiftFileSuffix(), against: pattern)
  case .filePath:
    return matchesFilePathFilter(relativePath: relativePath, pattern: pattern)
  case .typeName:
    return false
  }
}

/// Determine whether a type with the given `qualifiedName` (e.g. `MyClass` or
/// `Outer.Inner`) should be extracted, based on the include/exclude filters in
/// `config`.
///
/// Only type-name patterns (containing `.`) and plain patterns (no `/` or `.`)
/// are checked here. File-path patterns are skipped — use `shouldJExtractFile`
/// for those
func shouldJExtractType(qualifiedName: String, config: Configuration) -> Bool {
  if let includeFilters = config.swiftFilterInclude, !includeFilters.isEmpty {
    let typePatterns = includeFilters.filter { classifyPattern($0) != .filePath }
    if !typePatterns.isEmpty {
      let included = typePatterns.contains { pattern in
        let kind = classifyPattern(pattern)
        switch kind {
        case .typeName:
          return matchesTypeNameFilter(qualifiedName: qualifiedName, pattern: pattern)
        case .plain:
          // Plain pattern: match against the top-level name
          return matchSegment(qualifiedName.split(separator: ".").first.map(String.init) ?? qualifiedName, against: pattern)
        case .filePath:
          return false
        }
      }
      guard included else {
        return false
      }
    }
  }

  if let excludeFilters = config.swiftFilterExclude, !excludeFilters.isEmpty {
    let typePatterns = excludeFilters.filter { classifyPattern($0) != .filePath }
    let excluded = typePatterns.contains { pattern in
      let kind = classifyPattern(pattern)
      switch kind {
      case .typeName:
        return matchesTypeNameFilter(qualifiedName: qualifiedName, pattern: pattern)
      case .plain:
        return matchSegment(qualifiedName.split(separator: ".").first.map(String.init) ?? qualifiedName, against: pattern)
      case .filePath:
        return false
      }
    }
    if excluded {
      return false
    }
  }

  return true
}
