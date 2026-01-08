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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension String {
  /// For a String that's of the form java.util.Vector, return the "Vector" part.
  package var defaultSwiftNameForJavaClass: String {
    if let dotLoc = lastIndex(of: ".") {
      let afterDot = index(after: dotLoc)
      return String(self[afterDot...]).javaClassNameToCanonicalName.adjustedSwiftTypeName
    }

    return javaClassNameToCanonicalName.adjustedSwiftTypeName
  }
}

extension String {
  /// Convert a Java class name to its canonical name.
  /// Replaces `$` with `.` for nested classes but preserves `$` at the start of identifiers.
  package var javaClassNameToCanonicalName: String {
    let regex = try! Regex(#"(?<=\w)\$"#)
    return self.replacing(regex, with: ".")
  }

  /// Whether this is the name of an anonymous class.
  package var isLocalJavaClass: Bool {
    for segment in split(separator: "$") {
      if let firstChar = segment.first, firstChar.isNumber {
        return true
      }
    }

    return false
  }

  /// Adjust type name for "bad" type names that don't work well in Swift.
  package var adjustedSwiftTypeName: String {
    switch self {
    case "Type": return "JavaType"
    default: return self
    }
  }
}
