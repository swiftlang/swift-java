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

public protocol Storage {
  var name: String { get }

  func load() -> Int64
  func save(_ integer: Int64)
}

public func saveWithStorage(_ integer: Int64, s: any Storage) {
  s.save(integer);
}

public func loadWithStorage(s: any Storage) -> Int64 {
  return s.load();
}
