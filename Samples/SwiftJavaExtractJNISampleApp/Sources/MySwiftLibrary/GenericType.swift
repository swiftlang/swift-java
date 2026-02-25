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

public struct MyID<T> {
  public var rawValue: T
  public init(_ rawValue: T) {
    self.rawValue = rawValue
  }
  public var description: String {
    "\(rawValue)"
  }
}

public func makeIntID(_ value: Int) -> MyID<Int> {
  MyID(value)
}

public func makeStringID(_ value: String) -> MyID<String> {
  MyID(value)
}

public struct MyEntity {
  public var id: MyID<Int>
  public var name: String
  public init(id: MyID<Int>, name: String) {
    self.id = id
    self.name = name
  }
}

public enum GenericEnum<T> {
  case foo
  case bar
}

public func makeIntGenericEnum() -> GenericEnum<Int> {
  if Bool.random() { return .foo } else { return .bar }
}
