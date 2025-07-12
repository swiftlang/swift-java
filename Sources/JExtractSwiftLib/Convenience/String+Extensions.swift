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

  // TODO: naive implementation good enough for our simple case `methodMethodSomething` -> `MethodSomething`
  var toCamelCase: String {
    guard let f = first else {
      return self
    }

    return "\(f.uppercased())\(String(dropFirst()))"
  }

  /// Returns whether the string is of the format `isX`
  private var hasJavaBooleanNamingConvention: Bool {
    guard self.hasPrefix("is"), self.count > 2 else {
      return false
    }

    let thirdCharacterIndex = self.index(self.startIndex, offsetBy: 2)
    return self[thirdCharacterIndex].isUppercase
  }

  func javaGetterName(isBoolean: Bool) -> String {
    if !isBoolean {
      return "get\(self.toCamelCase)"
    } else if !hasJavaBooleanNamingConvention {
      return "is\(self.toCamelCase)"
    } else {
      return self.toCamelCase
    }
  }

  func javaSetterName(isBoolean: Bool) -> String {
    if !isBoolean || !hasJavaBooleanNamingConvention {
      return "set\(self.toCamelCase)"
    } else {
      return "setIs\(self.toCamelCase)"
    }
  }
}
