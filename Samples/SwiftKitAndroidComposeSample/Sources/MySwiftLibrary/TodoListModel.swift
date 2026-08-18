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

import Observation

/// Demonstrates **arrays**. Mutating the `items` array (append/remove) is an
/// observable change, so a Compose list that reads `items` should recompose.
@Observable
public class TodoListModel {
  public var items: [String] = ["Buy milk", "Walk the dog", "Learn swift-java"]

  public init() {}

  /// Read-only computed property derived from the array.
  public var count: Int64 {
    Int64(items.count)
  }

  public var isEmpty: Bool {
    items.isEmpty
  }

  public func add(_ item: String) {
    items.append(item)
  }

  public func removeLast() {
    if !items.isEmpty {
      items.removeLast()
    }
  }

  public func removeAll() {
    items.removeAll()
  }
}
