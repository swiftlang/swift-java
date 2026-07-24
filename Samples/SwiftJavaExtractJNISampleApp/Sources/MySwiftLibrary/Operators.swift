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

infix operator +-==*

public struct OperatorScore {
  public var value: Int64

  public init(value: Int64) {
    self.value = value
  }

  public static func + (left: OperatorScore, right: OperatorScore) -> OperatorScore {
    OperatorScore(value: left.value + right.value)
  }

  public static func - (left: OperatorScore, right: OperatorScore) -> OperatorScore {
    OperatorScore(value: left.value - right.value)
  }

  public static func * (left: OperatorScore, right: OperatorScore) -> OperatorScore {
    OperatorScore(value: left.value * right.value)
  }

  public static func / (left: OperatorScore, right: OperatorScore) -> OperatorScore {
    OperatorScore(value: left.value / right.value)
  }

  public static func +-==* (left: OperatorScore, right: OperatorScore) -> String {
    "Called +-==* in Java successfully with left: \(left.value) and right: \(right.value)"
  }
}
