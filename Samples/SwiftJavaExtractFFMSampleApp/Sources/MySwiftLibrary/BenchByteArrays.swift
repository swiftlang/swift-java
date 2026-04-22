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

// FFM mode supports [UInt8] and Data, but NOT [[UInt8]], UnsafeRawBufferPointer,
// or UnsafeMutableRawBufferPointer. The benchmark class on the Java side omits
// the unsupported cases.

// ==== -----------------------------------------------------------------------
// MARK: [UInt8] pass-through

public func benchAcceptBytes(_ bytes: [UInt8]) -> Int {
  bytes.count
}

public func benchReturnBytes(_ size: Int) -> [UInt8] {
  [UInt8](repeating: 0, count: size)
}

public func benchEchoBytes(_ bytes: [UInt8]) -> [UInt8] {
  bytes
}

// ==== -----------------------------------------------------------------------
// MARK: Data

public func benchAcceptData(_ data: Data) -> Int {
  data.count
}

public func benchReturnData(_ size: Int) -> Data {
  Data(count: size)
}

public func benchEchoData(_ data: Data) -> Data {
  data
}

// ==== -----------------------------------------------------------------------
// MARK: real world examples

public func benchSparseShard(
  dimension: Int32,
  numShards: Int32,
  indices: [Int32],
  values: [Int32],
  helperKey: [UInt8]
) -> [UInt8] {
  let outSize = Int(indices.count) * 40 + helperKey.count
  return [UInt8](repeating: 0, count: outSize)
}
