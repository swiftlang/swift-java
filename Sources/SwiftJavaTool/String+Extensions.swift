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

import Foundation
import ArgumentParser
import SwiftJavaToolLib
import SwiftJava
import JavaUtilJar
import SwiftJavaToolLib
import SwiftJavaConfigurationShared

extension String {
  /// For a String that's of the form java.util.Vector, return the "Vector"
  /// part.
  var defaultSwiftNameForJavaClass: String {
    if let dotLoc = lastIndex(of: ".") {
      let afterDot = index(after: dotLoc)
      return String(self[afterDot...]).javaClassNameToCanonicalName.adjustedSwiftTypeName
    }

    return javaClassNameToCanonicalName.adjustedSwiftTypeName
  }
}

extension String {
  /// Replace all of the $'s for nested names with "." to turn a Java class
  /// name into a Java canonical class name,
  var javaClassNameToCanonicalName: String {
    return replacing("$", with: ".")
  }

  /// Whether this is the name of an anonymous class.
  var isLocalJavaClass: Bool {
    for segment in split(separator: "$") {
      if let firstChar = segment.first, firstChar.isNumber {
        return true
      }
    }

    return false
  }

  /// Adjust type name for "bad" type names that don't work well in Swift.
  var adjustedSwiftTypeName: String {
    switch self {
    case "Type": return "JavaType"
    default: return self
    }
  }
}
