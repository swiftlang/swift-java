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

extension Dictionary {
  /// Same values, corresponding to mapped keys.
  public func mapKeys<Transformed>(
    _ transform: (Key) throws -> Transformed
  ) rethrows -> [Transformed: Value] {
    .init(
      uniqueKeysWithValues: try map {
        (try transform($0.key), $0.value)
      }
    )
  }

}

extension Collection {
  typealias IsLastElement = Bool
  var withIsLast: any Collection<(Element, IsLastElement)> {
    var i = 1
    let totalCount = self.count

    return self.map { element in
      let isLast = i == totalCount
      i += 1
      return (element, isLast)
    }
  }
}
