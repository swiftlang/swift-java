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

// Mirrors `Tuples.swift` in the JNI sample app, so that documentation can show
// one Swift example alongside its usage in both jextract modes

public func returnIntPair() -> (Int32, Int64) {
  (42, 43)
}

public func sumIntPair(pair: (Int32, Int64)) -> Int64 {
  Int64(pair.0) + pair.1
}

public func labeledTuple() -> (x: Int32, y: Int32) {
  (x: 10, y: 20)
}
