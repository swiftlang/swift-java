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

public struct VariadicBox<each T> {
  public var values: (repeat each T)
  public init(values: repeat each T) {
    self.values = (repeat each values)
  }

  public static var count: Int {
    ComputeParameterPackLength.count(ofPack: (repeat each T).self)
  }
}

public typealias IntStringBoolBox = VariadicBox<Int, String, Bool>

private enum ComputeParameterPackLength {
  enum BoolConverter<T> {
    typealias Bool = Swift.Bool
  }
  static func count<each T>(ofPack t: (repeat each T).Type) -> Int {
    MemoryLayout<(repeat BoolConverter<each T>.Bool)>.size / MemoryLayout<Bool>.stride
  }
}
