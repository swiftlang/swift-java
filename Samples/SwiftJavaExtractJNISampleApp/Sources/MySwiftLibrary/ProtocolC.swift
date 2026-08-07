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

public protocol ProtocolC: ProtocolB {
  var constantC: Int64 { get }
}

public struct ConcreteProtocolC: ProtocolC {
  public var constantB: Int64
  public var constantC: Int64
  public init(b: Int64, c: Int64) {
    constantB = b
    constantC = c
  }
}

public func makeProtocolC(b: Int64, c: Int64) -> any ProtocolC {
  ConcreteProtocolC(b: b, c: c)
}
