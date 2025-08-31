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

import SwiftJNI

extension String {

  var firstCharacterUppercased: String {
    guard let f = first else {
      return self
    }

    return "\(f.uppercased())\(String(dropFirst()))"
  }

  var firstCharacterLowercased: String {
    guard let f = first else {
      return self
    }

    return "\(f.lowercased())\(String(dropFirst()))"
  }

  /// Returns whether the string is of the format `isX`
  var hasJavaBooleanNamingConvention: Bool {
    guard self.hasPrefix("is"), self.count > 2 else {
      return false
    }

    let thirdCharacterIndex = self.index(self.startIndex, offsetBy: 2)
    return self[thirdCharacterIndex].isUppercase
  }

  /// Returns a version of the string correctly escaped for a JNI
  var escapedJNIIdentifier: String {
    self.map {
      if $0 == "_" {
        return "_1"
      } else if $0 == "/" {
        return "_"
      } else if $0 == ";" {
        return "_2"
      } else if $0 == "[" {
        return "_3"
      } else if $0.isASCII && ($0.isLetter || $0.isNumber)  {
        return String($0)
      } else if let utf16 = $0.utf16.first {
        // Escape any non-alphanumeric to their UTF16 hex encoding
        let utf16Hex = String(format: "%04x", utf16)
        return "_0\(utf16Hex)"
      } else {
        fatalError("Invalid JNI character: \($0)")
      }
    }
    .joined()
  }

  /// Looks up self as a SwiftJava wrapped class name and converts it
  /// into a `JavaType.class` if it exists in `lookupTable`.
  func parseJavaClassFromJavaKitName(in lookupTable: [String: String]) -> JavaType? {
    guard let canonicalJavaName = lookupTable[self] else {
      return nil
    }
    let nameParts = canonicalJavaName.components(separatedBy: ".")
    let javaPackageName = nameParts.dropLast().joined(separator: ".")
    let javaClassName = nameParts.last!

    return .class(package: javaPackageName, name: javaClassName)
  }
}
