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

public struct MySwiftStruct {
  private var cap: Int64
  public var len: Int64

  public init(cap: Int64, len: Int64) {
    self.cap = cap
    self.len = len
  }

  public func getCapacity() -> Int64 {
    self.cap
  }

  public mutating func increaseCap(by value: Int64) -> Int64 {
    precondition(value > 0)
    self.cap += value
    return self.cap
  }
}
