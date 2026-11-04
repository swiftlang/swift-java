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

extension String {

  package var firstCharacterUppercased: String {
    guard let f = first else {
      return self
    }

    return "\(f.uppercased())\(String(dropFirst()))"
  }

  package var firstCharacterLowercased: String {
    guard let f = first else {
      return self
    }

    return "\(f.lowercased())\(String(dropFirst()))"
  }

  /// If the string ends with `.swift`, return it without that suffix;
  /// otherwise return self unchanged
  package func dropSwiftFileSuffix() -> String {
    if hasSuffix(".swift") {
      return String(dropLast(".swift".count))
    }
    return self
  }

  /// Unescapes the name if it is surrounded by backticks.
  package var unescapedSwiftName: String {
    if count >= 2 && hasPrefix("`") && hasSuffix("`") {
      return String(dropFirst().dropLast())
    }
    return self
  }
}
