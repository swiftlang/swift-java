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

extension List: Sequence {
  public typealias Element = E
  public typealias Iterator = JavaIterator<E>

  public func makeIterator() -> Iterator {
    return self.iterator()!.as(JavaIterator<E>.self)!
  }
}

