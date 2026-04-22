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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// ==== -----------------------------------------------------------------------
// MARK: [UInt8] pass-through

public func benchAcceptBytes(_ bytes: [UInt8]) -> Int {
  bytes.count
}

public func benchReturnBytes(_ size: Int) -> [UInt8] {
  [UInt8](repeating: 0xff, count: size)
}

public func benchEchoBytes(_ bytes: [UInt8]) -> [UInt8] {
  bytes
}

// ==== -----------------------------------------------------------------------
// MARK: [[UInt8]] pass-through

public func benchAcceptNestedBytes(_ arrays: [[UInt8]]) -> Int {
  arrays.reduce(0) { $0 + $1.count }
}

public func benchReturnNestedBytes(_ outer: Int, _ inner: Int) -> [[UInt8]] {
  (0..<outer).map { _ in [UInt8](repeating: 0xff, count: inner) }
}

public func benchEchoNestedBytes(_ arrays: [[UInt8]]) -> [[UInt8]] {
  arrays
}

// ==== -----------------------------------------------------------------------
// MARK: UnsafeRawBufferPointer (JNI only)

public func benchAcceptBuffer(_ buf: UnsafeRawBufferPointer) -> Int {
  buf.count
}

public func benchAcceptMutableBuffer(_ buf: UnsafeMutableRawBufferPointer) -> Int {
  buf.count
}

// ==== -----------------------------------------------------------------------
// MARK: Data

public func benchAcceptData(_ data: Data) -> Int {
  data.count
}

public func benchReturnData(_ size: Int) -> Data {
  Data(repeating: 0xff, count: size)
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
  return [UInt8](repeating: 0xff, count: outSize)
}

public func benchDenseShard(
  dimension: Int32,
  numShards: Int32,
  measurement: [UInt8],
  helperKey: [UInt8]
) -> [[UInt8]] {
  let shardSize = measurement.count / Int(numShards)
  return (0..<Int(numShards)).map { _ in [UInt8](repeating: 0xff, count: shardSize) }
}
