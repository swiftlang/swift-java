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

extension String {
  /// Returns whether the string is of the format `isX` (Java Beans boolean
  /// property naming convention)
  package var hasJavaBooleanNamingConvention: Bool {
    guard self.hasPrefix("is"), self.count > 2 else {
      return false
    }

    let thirdCharacterIndex = self.index(self.startIndex, offsetBy: 2)
    return self[thirdCharacterIndex].isUppercase
  }
}
