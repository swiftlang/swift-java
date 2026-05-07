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

public struct ReefFish: Hashable {
  public var name: String

  public init(name: String) {
    self.name = name
  }
}

public func makeIntToFishDictionary() -> [Int: ReefFish] {
  [
    1: ReefFish(name: "salmon"),
    2: ReefFish(name: "clownfish"),
  ]
}

public func intToFishDictionary(dict: [Int: ReefFish]) -> [Int: ReefFish] {
  dict
}

public func insertIntoIntToFishDictionary(dict: [Int: ReefFish], key: Int, value: ReefFish) -> [Int: ReefFish] {
  var copy = dict
  copy[key] = value
  return copy
}

public func makeFishSet() -> Set<ReefFish> {
  [
    ReefFish(name: "salmon"),
    ReefFish(name: "clownfish"),
  ]
}

public func fishSet(set: Set<ReefFish>) -> Set<ReefFish> {
  set
}

public func insertIntoFishSet(set: Set<ReefFish>, fish: ReefFish) -> Set<ReefFish> {
  var copy = set
  copy.insert(fish)
  return copy
}
