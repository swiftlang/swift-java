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
  private var subscriptValue: Int64
  private var subscriptArray: [Int64]

  public init(cap: Int64, len: Int64) {
    self.cap = cap
    self.len = len
    self.subscriptValue = 0
    self.subscriptArray = [10, 20, 15, 75]
  }

  public init?(doInit: Bool) {
      if doInit {
        self.init(cap: 10, len: 10)
      } else {
        return nil
      }
    }

  public func getCapacity() -> Int64 {
    self.cap
  }

  public mutating func increaseCap(by value: Int64) -> Int64 {
    precondition(value > 0)
    self.cap += value
    return self.cap
  }

  public func getSubscriptValue() -> Int64 {
    return self.subscriptValue
  }

  public func getSubscriptArrayValue(index: Int64) -> Int64 {
    return self.subscriptArray[Int(index)]
  }

  public subscript() -> Int64 {
    get { return subscriptValue }
    set { subscriptValue = newValue }
  }

  public subscript(index: Int64) -> Int64 {
    get { return subscriptArray[Int(index)] }
    set { subscriptArray[Int(index)] = newValue }
  }
}
