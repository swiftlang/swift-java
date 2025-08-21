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

public protocol SomeProtocol {
  var constant: Int64 { get }
  var mutable: Int64 { get set }

  func name() -> String
}

public class ConcreteSomeProtocol: SomeProtocol {
  public let constant: Int64 = 42
  public var mutable: Int64 = 0

  public func name() -> String {
    return "ConcreteSomeProtocol"
  }
}

public func takeProtocol(_ proto: some SomeProtocol) -> Int64 {
  return proto.constant
}
