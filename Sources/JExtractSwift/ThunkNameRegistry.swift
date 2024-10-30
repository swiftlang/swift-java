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

/// Registry of names we've already emitted as @_cdecl and must be kept unique.
/// In order to avoid duplicate symbols, the registry can append some unique identifier to duplicated names
package struct ThunkNameRegistry {
  /// Maps base names such as "swiftjava_Module_Type_method_a_b_c" to the number of times we've seen them.
  /// This is used to de-duplicate symbols as we emit them.
  private var baseNames: [String: Int] = [:]

  package init() {}

  package mutating func deduplicate(name: String) -> String {
    var emittedCount = self.baseNames[name, default: 0]
    self.baseNames[name] = emittedCount + 1

    if emittedCount == 0 {
      return name // first occurrence of a name we keep as-is
    } else {
      return "\(name)$\(emittedCount)"
    }
  }
}