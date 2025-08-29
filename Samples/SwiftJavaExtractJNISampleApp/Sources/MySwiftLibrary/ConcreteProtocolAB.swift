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

public class ConcreteProtocolAB: ProtocolA, ProtocolB {
  public let constantA: Int64
  public let constantB: Int64
  public var mutable: Int64 = 0

  public func name() -> String {
    return "ConcreteProtocolAB"
  }

  public init(constantA: Int64, constantB: Int64) {
    self.constantA = constantA
    self.constantB = constantB
  }
}
