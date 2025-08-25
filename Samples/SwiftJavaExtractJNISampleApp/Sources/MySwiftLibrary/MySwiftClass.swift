//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJava

public class MySwiftClass {
  public let x: Int64
  public let y: Int64

  public let byte: UInt8 = 0
  public let constant: Int64 = 100
  public var mutable: Int64 = 0
  public var product: Int64 {
    return x * y
  }
  public var throwingVariable: Int64 {
    get throws {
      throw MySwiftClassError.swiftError
    }
  }
  public var mutableDividedByTwo: Int64 {
    get {
      return mutable / 2
    }
    set {
      mutable = newValue * 2
    }
  }
  public let warm: Bool = false
  public var getAsync: Int64 {
    get async {
      return 42
    }
  }

  public static func method() {
    p("Hello from static method in a class!")
  }

  public init(x: Int64, y: Int64) {
    self.x = x
    self.y = y
    p("\(self)")
  }

  public init() {
    self.x = 10
    self.y = 5
  }

  deinit {
    p("deinit called!")
  }

  public func sum() -> Int64 {
    return x + y
  }

  public func xMultiplied(by z: Int64) -> Int64 {
    return x * z;
  }

  enum MySwiftClassError: Error {
    case swiftError
  }

  public func throwingFunction() throws {
    throw MySwiftClassError.swiftError
  }

  public func sumX(with other: MySwiftClass) -> Int64 {
    return self.x + other.x
  }

  public func copy() -> MySwiftClass {
    return MySwiftClass(x: self.x, y: self.y)
  }

  public func addXWithJavaLong(_ other: JavaLong) -> Int64 {
    return self.x + other.longValue()
  }
}
