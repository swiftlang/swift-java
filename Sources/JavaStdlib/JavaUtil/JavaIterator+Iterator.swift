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
import SwiftJava

extension JavaIterator: IteratorProtocol {
  public typealias Element = E

  public func next() -> E? {
    if hasNext() {
      let nextResult: JavaObject? = next()
      return nextResult.map { $0.as(E.self)! }
    }

    return nil
  }
}
