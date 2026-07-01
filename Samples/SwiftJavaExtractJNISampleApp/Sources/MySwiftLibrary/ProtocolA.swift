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
  func makeClass() -> MySwiftClass
}

public func takeProtocol(_ proto1: any ProtocolA, _ proto2: some ProtocolA) -> Int64 {
  proto1.constantA + proto2.constantA
}

/// A struct conformer to `ProtocolA`, used to prove that
/// setter dispatch through a returned existential box
public struct ConcreteProtocolAStruct: ProtocolA {
  public let constantA: Int64
  public var mutable: Int64 = 0

  public init(constantA: Int64) {
    self.constantA = constantA
  }

  public func name() -> String {
    "ConcreteProtocolAStruct"
  }

  public func makeClass() -> MySwiftClass {
    MySwiftClass(x: constantA, y: mutable)
  }
}

/// Returns a value-type `ProtocolA` conformer boxed as `any ProtocolA`.
public func makeProtocolA(constantA: Int64) -> any ProtocolA {
  ConcreteProtocolAStruct(constantA: constantA)
}
