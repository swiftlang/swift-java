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

public func makeStringSet() -> Set<String> {
  ["hello", "world"]
}

public func stringSet(set: Set<String>) -> Set<String> {
  set
}

public func insertIntoStringSet(set: Set<String>, element: String) -> Set<String> {
  var copy = set
  copy.insert(element)
  return copy
}

public func makeIntegerSet() -> Set<Int32> {
  [1, 2, 3]
}

public func integerSet(set: Set<Int32>) -> Set<Int32> {
  set
}

public func makeLongSet() -> Set<Int> {
  [10, 20, 30]
}

public func longSet(set: Set<Int>) -> Set<Int> {
  set
}
