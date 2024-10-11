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
}
