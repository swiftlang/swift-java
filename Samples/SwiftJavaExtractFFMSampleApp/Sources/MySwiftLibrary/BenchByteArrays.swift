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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// ==== -----------------------------------------------------------------------
// MARK: [UInt8] pass-through

public func acceptBytes(_ bytes: [UInt8]) -> Int {
  bytes.count
}

public func returnBytes(_ size: Int) -> [UInt8] {
  [UInt8](repeating: 0xff, count: size)
}

public func echoBytes(_ bytes: [UInt8]) -> [UInt8] {
  bytes
}

// ==== -----------------------------------------------------------------------
// MARK: Data

public func acceptData(_ data: Data) -> Int {
  data.count
}

public func returnData(_ size: Int) -> Data {
  Data(repeating: 0xff, count: size)
}

// ==== -----------------------------------------------------------------------
// MARK: large multi-parameter function

public func largeFunction(
  a: Int32,
  b: [UInt8],
  c: [Int32],
  d: [UInt8]
) -> [UInt8] {
  let outSize = b.count + d.count + c.count * 4
  return [UInt8](repeating: 0xff, count: outSize)
}
