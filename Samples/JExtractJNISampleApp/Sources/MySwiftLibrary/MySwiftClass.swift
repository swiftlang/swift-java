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

public class MySwiftClass {
  let x: Int64
  let y: Int64

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
}
