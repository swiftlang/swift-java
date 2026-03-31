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

  private var cap: Int
  private var len: Int
  private var subscriptValue: Int
  private var subscriptArray: [Int]

  public init(cap: Int, len: Int) {
    self.cap = cap
    self.len = len
    self.subscriptValue = 0
    self.subscriptArray = [10, 20, 15, 75]
  }

  public func voidMethod() {
  }

  public func takeIntMethod(i: Int) {
  }

  public func echoIntMethod(i: Int) -> Int {
    i
  }

  public func makeIntMethod() -> Int {
    12
  }

  public func getCapacity() -> Int {
    self.cap
  }

  public func getLength() -> Int {
    self.len
  }

  public func withCapLen(_ body: (Int, Int) -> Void) {
    body(cap, len)
  }

  public mutating func increaseCap(by value: Int) -> Int {
    precondition(value > 0)
    self.cap += value
    return self.cap
  }

  public func makeRandomIntMethod() -> Int {
    Int.random(in: 1..<256)
  }

  public func getSubscriptValue() -> Int {
    self.subscriptValue
  }

  public func getSubscriptArrayValue(index: Int) -> Int {
    self.subscriptArray[index]
  }

  public subscript() -> Int {
    get { subscriptValue }
    set { subscriptValue = newValue }
  }

  public subscript(index: Int) -> Int {
    get { subscriptArray[index] }
    set { subscriptArray[index] = newValue }
  }

  // operator functions are ignored.
  public static func == (lhs: MySwiftStruct, rhs: MySwiftStruct) -> Bool {
    false
  }
}
