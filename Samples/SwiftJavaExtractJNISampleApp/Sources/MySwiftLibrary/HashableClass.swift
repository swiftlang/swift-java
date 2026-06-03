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

public class HashableClass: Hashable {
  public let value: Int
  public init(value: Int) {
    self.value = value
  }

  public static func == (lhs: HashableClass, rhs: HashableClass) -> Bool {
    lhs.value == rhs.value
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }
}

public class HashableSubclass: HashableClass {
  public override init(value: Int) {
    super.init(value: value)
  }
}
