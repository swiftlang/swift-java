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

  public var len: Int
  public var cap: Int

  public init(len: Int, cap: Int) {
    self.len = len
    self.cap = cap

    p("\(MySwiftClass.self).len = \(self.len)")
    p("\(MySwiftClass.self).cap = \(self.cap)")
    let addr = unsafeBitCast(self, to: UInt64.self)
    p("initializer done, self = 0x\(String(addr, radix: 16, uppercase: true))")
  }

  deinit {
    let addr = unsafeBitCast(self, to: UInt64.self)
    p("Deinit, self = 0x\(String(addr, radix: 16, uppercase: true))")
  }

  public var counter: Int32 = 0

  public func voidMethod() {
    p("")
  }

  public func takeIntMethod(i: Int) {
    p("i:\(i)")
  }

  public func echoIntMethod(i: Int) -> Int {
    p("i:\(i)")
    return i
  }

  public func makeIntMethod() -> Int {
    p("make int -> 12")
    return 12
  }

  public func makeRandomIntMethod() -> Int {
    return Int.random(in: 1..<256)
  }
}
