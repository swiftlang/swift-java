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

public protocol ProtocolWithStatic {
  // static requirements are not yet supported.
  static func myFunc() -> Int
  init()
}

public func useProtocolWithStatic(_ value: any ProtocolWithStatic) -> Int {
  let meta = type(of: value)
  return meta.myFunc()
}

public protocol ProtocolWithStaticProperty {
  static var value: Int { get }
}

public func useProtocolWithStaticProperty(_ value: any ProtocolWithStaticProperty) -> Int {
  let meta = type(of: value)
  return meta.value
}
