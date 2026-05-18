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

public func makeIntToFishDictionary() -> [Int: Fish] {
  [
    1: Fish(name: "salmon"),
    2: Fish(name: "clownfish"),
  ]
}

public func intToFishDictionary(dict: [Int: Fish]) -> [Int: Fish] {
  dict
}

public func makeFishSet() -> Set<Fish> {
  [
    Fish(name: "salmon"),
    Fish(name: "clownfish"),
  ]
}

public func fishSet(set: Set<Fish>) -> Set<Fish> {
  set
}

public func makeMyIDToFish() -> [MyID<Int>: Fish] {
  [
    .init(0): Fish(name: "salmon"),
    .init(1): Fish(name: "clownfish"),
  ]
}

public func makeSpecializedGenericTypeSet() -> Set<FishBox> {
  [.init(count: 2), .init(count: 3)]
}

public func makeSetInDictionary() -> [String: Set<Int32>] {
  [
    "even": [0, 2, 4],
    "odd": [1, 3, 5],
  ]
}

public func makeIntArrayDictionary() -> [String: [Int32]] {
  [
    "even": [0, 2, 4],
    "odd": [1, 3, 5],
  ]
}

public func intArrayDictionary(dict: [String: [Int32]]) -> [String: [Int32]] {
  dict
}

public func makeFishArrayDictionary() -> [String: [Fish]] {
  [
    "reef": [
      Fish(name: "clownfish"),
      Fish(name: "blue tang"),
    ],
    "river": [
      Fish(name: "salmon")
    ],
  ]
}

public func fishArrayDictionary(dict: [String: [Fish]]) -> [String: [Fish]] {
  dict
}

public func makeOptionalFishDictionary() -> [String: Fish?] {
  [
    "reef": Fish(name: "clownfish"),
    "empty": nil,
  ]
}

public func optionalFishDictionary(dict: [String: Fish?]) -> [String: Fish?] {
  dict
}
