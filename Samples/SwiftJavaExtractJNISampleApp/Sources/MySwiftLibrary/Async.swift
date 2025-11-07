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

public func asyncSum(i1: Int64, i2: Int64) async -> Int64 {
  return i1 + i2
}

public func asyncSleep() async throws {
  try await Task.sleep(for: .milliseconds(500))
}

public func asyncCopy(myClass: MySwiftClass) async throws -> MySwiftClass {
  let new = MySwiftClass(x: myClass.x, y: myClass.y)
  try await Task.sleep(for: .milliseconds(500))
  return new
}

public func asyncOptional(i: Int64) async throws -> Int64? {
  try await Task.sleep(for: .milliseconds(100))
  return i
}

public func asyncThrows() async throws {
  throw MySwiftError.swiftError
}

public func asyncString(input: String) async -> String {
  return input
}
