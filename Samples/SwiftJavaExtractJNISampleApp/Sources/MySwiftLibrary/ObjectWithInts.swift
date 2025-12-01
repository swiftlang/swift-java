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

public final class ObjectWithInts {
  public var normalInt: Int
  public var unsignedInt: UInt

  public init(normalInt: Int, unsignedInt: UInt) {
    self.normalInt = normalInt
    self.unsignedInt = unsignedInt
  }

  public func callMe(arg: UInt) -> UInt {
    return arg
  }
}
