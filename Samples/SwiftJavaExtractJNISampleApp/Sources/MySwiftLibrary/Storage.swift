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

import SwiftJava

public class StorageItem {
  public let value: Int64

  public init(value: Int64) {
    self.value = value
  }
}

public protocol Storage {
  func load() -> StorageItem
  func save(_ item: StorageItem)
}

public func saveWithStorage(_ item: StorageItem, s: any Storage) {
  s.save(item);
}

public func loadWithStorage(s: any Storage) -> StorageItem {
  return s.load();
}
