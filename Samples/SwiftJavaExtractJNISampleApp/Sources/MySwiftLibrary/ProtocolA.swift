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

public protocol ProtocolA {
  var constantA: Int64 { get }
  var mutable: Int64 { get set }

  func name() -> String
}

public func takeProtocol(_ proto1: any ProtocolA, _ proto2: some ProtocolA) -> Int64 {
  return proto1.constantA + proto2.constantA
}
