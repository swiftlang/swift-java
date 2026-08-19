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
  public var x: Int
  public var y: Int

  // Mirrors `MySwiftClass` in the JNI sample app, so that documentation can
  // show one Swift example alongside its usage in both jextract modes
  public init(x: Int, y: Int) {
    self.x = x
    self.y = y
  }

  public init() {
    self.x = 10
    self.y = 5
  }

  deinit {
  }

  public var counter: Int32 = 0

  public static func factory(x: Int, y: Int) -> MySwiftClass {
    MySwiftClass(x: x, y: y)
  }

  public class func classMethod(x: Int) -> Int {
    x * 2
  }

  public class var classVariable: Int {
    42
  }

  public func sum() -> Int {
    x + y
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

  public func describe() -> String {
    "MySwiftClass(x: \(x), y: \(y))"
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
