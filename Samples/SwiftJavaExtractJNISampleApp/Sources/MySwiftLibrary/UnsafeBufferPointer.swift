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

private let int32BufferStorage: [Int32] = [10, 20, 30, 40]
private let emptyInt32BufferStorage: [Int32] = []
private var mutableInt32BufferStorage: [Int32] = [5, 10, 15]

public func makeInt32Buffer() -> UnsafeBufferPointer<Int32> {
  int32BufferStorage.withUnsafeBufferPointer { $0 }
}

public func makeEmptyInt32Buffer() -> UnsafeBufferPointer<Int32> {
  emptyInt32BufferStorage.withUnsafeBufferPointer { $0 }
}

public func sumInt32Buffer(data: UnsafeBufferPointer<Int32>) -> Int64 {
  data.reduce(0) { $0 + Int64($1) }
}

public func makeMutableInt32Buffer() -> UnsafeMutableBufferPointer<Int32> {
  mutableInt32BufferStorage.withUnsafeMutableBufferPointer { $0 }
}

public func sumMutableInt32Buffer(data: UnsafeMutableBufferPointer<Int32>) -> Int64 {
  data.reduce(0) { $0 + Int64($1) }
}

public func mutableInt32BufferElement(data: UnsafeMutableBufferPointer<Int32>, index: Int32) -> Int32 {
  data[Int(index)]
}

public func incrementMutableInt32Buffer(data: UnsafeMutableBufferPointer<Int32>) {
  for index in data.indices {
    data[index] += 1
  }
}
