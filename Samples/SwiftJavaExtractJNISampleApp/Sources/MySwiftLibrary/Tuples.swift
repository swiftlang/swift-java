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

public func returnPair() -> (Int64, String) {
  (42, "hello")
}

public func takePair(pair: (Int64, String)) -> String {
  "\(pair.0):\(pair.1)"
}

public func labeledTuple() -> (x: Int32, y: Int32) {
  (x: 10, y: 20)
}

public func echoTriple(triple: (Bool, Double, Int64)) -> (Bool, Double, Int64) {
  triple
}

public func makeBigTuple() -> (
  Bool, Int8, Int16, UInt16,
  Int32, Int64, Float, Double,
  String, Bool, Int8, Int16,
  UInt16, Int32, Int64, Float
) {
  (
    true, 1, 2, 3,
    4, 5, 6.0, 7.0,
    "eight", false, 9, 10,
    11, 12, 13, 14.0
  )
}
