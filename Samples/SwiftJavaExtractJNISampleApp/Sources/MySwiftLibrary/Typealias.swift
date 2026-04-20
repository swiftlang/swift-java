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

public typealias Amount = Double

public struct TypealiasUser {
  public var amount: Amount

  public init(amount: Amount) {
    self.amount = amount
  }

  public func doubled() -> Amount {
    amount * 2
  }
}

public func makeAmount(_ value: Amount) -> Amount {
  value
}

// Generic typealias used with a use-site argument. The alias's generic
// parameter `T` is substituted at the use site so `Maybe<Int64>` resolves
// to `Optional<Int64>`, which is `java.lang.OptionalLong` in Java.
public typealias Maybe<T> = T?

public func unwrapOrZero(_ value: Maybe<Int64>) -> Int64 {
  value ?? 0
}
