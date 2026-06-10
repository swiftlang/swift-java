//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaLangReflect
import SwiftJava

private let wellKnownJavaMemberNames: Set<String> = [
  "equals",
  "hashCode",
  "toString",
  "clone",
  "finalize",
  "wait",
  "notify",
  "notifyAll",
  "getClass",
]

private func primaryName(forMethodNamed name: String) -> String {
  func dropPrefix(_ name: String, _ prefix: String) -> String? {
    guard name.count > prefix.count, name.hasPrefix(prefix) else { return nil }
    let next = name[name.index(name.startIndex, offsetBy: prefix.count)]
    guard next.isUppercase else { return nil }
    return String(name.dropFirst(prefix.count))
  }
  if let stripped = dropPrefix(name, "get") { return stripped.lowercased() }
  if let stripped = dropPrefix(name, "set") { return stripped.lowercased() }
  if let stripped = dropPrefix(name, "is") { return stripped.lowercased() }
  return name.lowercased()
}

extension Swift.Array where Element == JavaLangReflect.Method {
  func sortedForEmission() -> [JavaLangReflect.Method] {
    sorted { lhs, rhs in
      let lhsName = lhs.getName()
      let rhsName = rhs.getName()
      let lhsBucket = wellKnownJavaMemberNames.contains(lhsName) ? 1 : 0
      let rhsBucket = wellKnownJavaMemberNames.contains(rhsName) ? 1 : 0
      if lhsBucket != rhsBucket { return lhsBucket < rhsBucket }
      let lhsPrimary = primaryName(forMethodNamed: lhsName)
      let rhsPrimary = primaryName(forMethodNamed: rhsName)
      if lhsPrimary != rhsPrimary { return lhsPrimary < rhsPrimary }
      if lhsName != rhsName { return lhsName < rhsName }
      return lhs.toGenericString() < rhs.toGenericString()
    }
  }
}

extension Swift.Array where Element == JavaLangReflect.Field {
  func sortedForEmission() -> [JavaLangReflect.Field] {
    sorted { $0.getName() < $1.getName() }
  }
}

extension Swift.Array where Element == Constructor<JavaObject> {
  func sortedForEmission() -> [Constructor<JavaObject>] {
    sorted { $0.toGenericString() < $1.toGenericString() }
  }
}
