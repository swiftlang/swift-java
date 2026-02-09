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

// This is a "plain Swift" file containing various types of declarations,
// that is exported to Java by using the `jextract-swift` tool.
//
// No annotations are necessary on the Swift side to perform the export.

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

public class MySwiftClass {

  public var len: Int
  public var cap: Int

  public init(len: Int, cap: Int) {
    self.len = len
    self.cap = cap
  }

  deinit {
  }

  public var counter: Int32 = 0

  public func voidMethod() {
  }

  public func takeIntMethod(i: Int) {
  }

  public func echoIntMethod(i: Int) -> Int {
    return i
  }

  public func makeIntMethod() -> Int {
    return 12
  }

  public func makeRandomIntMethod() -> Int {
    return Int.random(in: 1..<256)
  }
}