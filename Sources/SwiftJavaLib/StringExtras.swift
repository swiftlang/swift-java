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
import SwiftParser

extension String {
  /// Split the Swift type name into parent type + innermost type name.
  func splitSwiftTypeName() -> (parentType: String?, name: String) {
    guard let lastDot = lastIndex(of: ".") else {
      return (parentType: nil, name: self)
    }

    return (
      parentType: String(self[startIndex..<lastDot]),
      name: String(suffix(from: index(after: lastDot)))
    )
  }

  /// Escape a name with backticks if it's a Swift keyword.
  var escapedSwiftName: String {
    if isValidSwiftIdentifier(for: .variableName) {
      return self
    }

    return "`\(self)`"
  }

  /// Replace all occurrences of one character in the string with another.
  public func replacing(_ character: Character, with replacement: Character) -> String {
    return replacingOccurrences(of: String(character), with: String(replacement))
  }

  public func optionalWrappedType() -> String? {
    if self == "JavaOptionalInt!" || self == "JavaOptionalInt?" {
      return "Int32?"
    } else if self == "JavaOptionalLong!" || self == "JavaOptionalLong?" {
      return "Int64?"
    } else if self == "JavaOptionalDouble!" || self == "JavaOptionalDouble?" {
      return "Double?"
    } else if hasPrefix("JavaOptional<") {
      let offsetCount = "JavaOptional<".count
      return "\(String(self[index(startIndex, offsetBy: offsetCount)..<lastIndex(of: ">")!]))?"
    } else {
      return nil
    }
  }
}
