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
  private var registry: [ImportedFunc: String] = [:]
  private var duplicateNames: [String: Int] = [:]

  package init() {}

  package mutating func functionThunkName(
    module: String, decl: ImportedFunc,
    file: String = #fileID, line: UInt = #line) -> String {
    if let existingName = self.registry[decl] {
      return existingName
    }

    let params = decl.effectiveParameters(paramPassingStyle: .swiftThunkSelf)
    var paramsPart = ""
    if !params.isEmpty {
      paramsPart = "_" + params.map { param in
        param.firstName ?? "_"
      }.joined(separator: "_")
    }

    let name =
      if let parent = decl.parent {
        "swiftjava_\(module)_\(parent.swiftTypeName)_\(decl.baseIdentifier)\(paramsPart)"
      } else {
        "swiftjava_\(module)_\(decl.baseIdentifier)\(paramsPart)"
      }

    let emittedCount = self.duplicateNames[name, default: 0]
    defer { self.duplicateNames[name] = emittedCount + 1 }

    let deduplicatedName =
      if emittedCount == 0 {
        name  // first occurrence of a name we keep as-is
      } else {
        "\(name)$\(emittedCount)"
      }

    // Store the name we assigned to this specific decl.
    self.registry[decl] = deduplicatedName
    return deduplicatedName
  }
}
