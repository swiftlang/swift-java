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

extension SwiftJava {
  /// Some types we cannot handle importing, so we hardcode skipping them.
  public static let ExcludedJDKTypes: Set<String> = [
    "java.lang.Enum",
    "java.lang.Enum$EnumDesc",
  ]

  static func shouldImport(javaCanonicalName: String, filterInclude: [String], filterExclude: [String]) -> Bool {
    if SwiftJava.ExcludedJDKTypes.contains(javaCanonicalName) {
      return false
    }

    if !filterInclude.isEmpty {
      let anyIncludeMatches = filterInclude.contains(where: { javaCanonicalName.hasPrefix($0) })
      guard anyIncludeMatches else {
        return false
      }
    }

    for exclude in filterExclude {
      if javaCanonicalName.hasPrefix(exclude) {
        return false
      }
    }

    return true
  }
}
