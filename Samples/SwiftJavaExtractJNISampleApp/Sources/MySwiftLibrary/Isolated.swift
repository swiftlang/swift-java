//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJava

public actor Counter {
  var value: Int64 = 0

  public init() {}
}

public func increment(_ counter: isolated Counter, by amount: Int64) -> Int64 {
  counter.value += amount
  return counter.value
}

public func reset(_ counter: isolated Counter) -> Int64 {
  let value = counter.value
  counter.value = 0
  return value
}

public func incrementThrows(_ counter: isolated Counter) throws -> Int64 {
  throw MySwiftError.swiftError
}
