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

public class EquatableClass: Equatable {
  public let value: Int
  public init(value: Int) {
    self.value = value
  }

  public static func == (lhs: EquatableClass, rhs: EquatableClass) -> Bool {
    lhs.value == rhs.value
  }
}

public class EquatableSubclass: EquatableClass {
  public override init(value: Int) {
    super.init(value: value)
  }
}
