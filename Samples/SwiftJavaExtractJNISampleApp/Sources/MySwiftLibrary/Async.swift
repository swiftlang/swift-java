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

public func asyncCopy(myClass: MySwiftClass) async -> MySwiftClass {
  let new = MySwiftClass(x: myClass.x, y: myClass.y)
  try? await Task.sleep(for: .milliseconds(500))
  return new
}
