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

  static func shouldImport(javaCanonicalName: String, commonOptions: SwiftJava.CommonOptions) -> Bool {
    if SwiftJava.ExcludedJDKTypes.contains(javaCanonicalName) {
      return false
    }

    for include in commonOptions.filterInclude {
      guard javaCanonicalName.hasPrefix(include) else {
        // Skip classes which don't match our expected prefix
        return false
      }
    }

    for exclude in commonOptions.filterExclude {
      if javaCanonicalName.hasPrefix(exclude) {
        return false
      }
    }

    return true
  }
}
