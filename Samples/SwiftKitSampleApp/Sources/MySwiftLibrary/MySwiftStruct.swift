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

  public var number: Int

  public init(number: Int) {
    self.number = number
  }

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
