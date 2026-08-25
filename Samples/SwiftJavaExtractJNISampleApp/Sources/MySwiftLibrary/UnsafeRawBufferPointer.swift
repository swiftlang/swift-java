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

// snippet.rawBufferDefinition
/// Sum all bytes in the buffer
public func sumOfBytes(data: UnsafeRawBufferPointer) -> Int64 {
  var sum: Int64 = 0
  for byte in data {
    sum += Int64(byte)
  }
  return sum
}

/// Return the count of bytes in the buffer
public func bufferCount(data: UnsafeRawBufferPointer) -> Int64 {
  Int64(data.count)
}
//snippet.end

private let rawBufferStorage: [UInt8] = [10, 20, 30, 40]
private let emptyRawBufferStorage: [UInt8] = []
private var mutableRawBufferStorage: [UInt8] = [5, 10, 15]

public func makeRawBuffer() -> UnsafeRawBufferPointer {
  rawBufferStorage.withUnsafeBytes { $0 }
}

public func makeEmptyRawBuffer() -> UnsafeRawBufferPointer {
  emptyRawBufferStorage.withUnsafeBytes { $0 }
}

public func makeMutableRawBuffer() -> UnsafeMutableRawBufferPointer {
  mutableRawBufferStorage.withUnsafeMutableBytes { $0 }
}
