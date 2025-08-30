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

public protocol ProtocolB {
  var constantB: Int64 { get }
}

public func takeCombinedProtocol(_ proto: some ProtocolA & ProtocolB) -> Int64 {
  return proto.constantA + proto.constantB
}

public func takeGenericProtocol<First: ProtocolA, Second: ProtocolB>(_ proto1: First, _ proto2: Second) -> Int64 {
  return proto1.constantA + proto2.constantB
}

public func takeCombinedGenericProtocol<T: ProtocolA & ProtocolB>(_ proto: T) -> Int64 {
  return proto.constantA + proto.constantB
}
