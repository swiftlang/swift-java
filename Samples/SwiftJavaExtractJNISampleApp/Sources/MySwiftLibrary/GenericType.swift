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

public enum MyIDs {
  public static func makeIntID(_ value: Int) -> MyID<Int> {
    MyID(value)
  }

  public static func takeIntValue(from value: MyID<Int>) -> Int {
    value.rawValue
  }

  public static func makeStringID(_ value: String) -> MyID<String> {
    MyID(value)
  }

  public static func takeStringValue(from value: MyID<String>) -> String {
    value.rawValue
  }

  public static func makeIDs(_ stringValue: String, _ intValue: Int) -> (MyID<String>, MyID<Int>) {
    (MyID(stringValue), MyID(intValue))
  }

  public static func takeValuesFromTuple(_ tuple: (MyID<String>, MyID<Int>)) -> (String, Int) {
    (tuple.0.rawValue, tuple.1.rawValue)
  }

  // public static func makeBoolIDArray(_ value: Bool, length: Int) -> [MyID<Bool>] {
  //   Array(repeating: MyID(value), count: length)
  // }

  // public static func takeBoolValues(from ids: [MyID<Bool>]) -> [Bool] {
  //   ids.map { $0.rawValue }
  // }

  public static func makeDoubleIDOptional(_ value: Double) -> MyID<Double>? {
    MyID(value)
  }

  public static func takeDoubleValueOptional(from id: MyID<Double>?) -> Double? {
    id?.rawValue
  }

  public static func takeDoubleValue(from value: MyID<Double>) -> Double {
    value.rawValue
  }

  public static func makeOptionalIntID(_ value: Int?) -> MyID<Int?> {
    MyID(value)
  }

  public static func takeOptionalIntValue(from id: MyID<Int?>) -> Int? {
    id.rawValue
  }
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
