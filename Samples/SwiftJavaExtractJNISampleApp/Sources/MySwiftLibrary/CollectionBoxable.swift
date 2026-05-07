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
