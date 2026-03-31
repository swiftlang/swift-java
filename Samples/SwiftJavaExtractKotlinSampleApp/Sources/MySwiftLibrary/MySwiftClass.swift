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

public class MySwiftClass {

  public let byte: UInt8 = 0
  public var len: Int
  public var cap: Int

  public init(len: Int, cap: Int) {
    self.len = len
    self.cap = cap
  }

  deinit {
  }

  public var counter: Int32 = 0

  public static func factory(len: Int, cap: Int) -> MySwiftClass {
    MySwiftClass(len: len, cap: cap)
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

  public func makeRandomIntMethod() -> Int {
    Int.random(in: 1..<256)
  }

  public func takeUnsignedChar(arg: UInt16) {
  }

  public func takeUnsignedInt(arg: UInt32) {
  }

  public func takeUnsignedLong(arg: UInt64) {
  }
}
