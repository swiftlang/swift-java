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
  try? await Task.sleep(for: .milliseconds(500))
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

public func asyncRunningSum() async -> Int64 {
    let totalSum = await withTaskGroup(of: Int64.self) { group in
        // 1. Add child tasks to the group
        for number in stride(from: Int64(1), through: 100, by: 1) {
            group.addTask {
                try? await Task.sleep(for: .milliseconds(number))
                return number
            }
        }

        var collectedSum: Int64 = 0

        // `for await ... in group` loops as each child task completes,
        // (not necessarily in the order they were added).
        for await number in group {
            collectedSum += number
        }

        return collectedSum
    }

    // This is the value returned by the `withTaskGroup` closure.
    return totalSum
}
