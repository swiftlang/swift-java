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

import SwiftJava

public protocol CallbackProtocol {
  func withBool(_ input: Bool) -> Bool
  func withInt8(_ input: Int8) -> Int8
  func withUInt16(_ input: UInt16) -> UInt16
  func withInt16(_ input: Int16) -> Int16
  func withInt32(_ input: Int32) -> Int32
  func withInt64(_ input: Int64) -> Int64
  func withFloat(_ input: Float) -> Float
  func withDouble(_ input: Double) -> Double
  func withString(_ input: String) -> String
  func withVoid()
  func withObject(_ input: MySwiftClass) -> MySwiftClass
  func withOptionalObject(_ input: MySwiftClass?) -> Optional<MySwiftClass>
}

public struct CallbackOutput {
  public let bool: Bool
  public let int8: Int8
  public let uint16: UInt16
  public let int16: Int16
  public let int32: Int32
  public let int64: Int64
  public let _float: Float
  public let _double: Double
  public let string: String
  public let object: MySwiftClass
  public let optionalObject: MySwiftClass?
}

public func outputCallbacks(
  _ callbacks: some CallbackProtocol,
  bool: Bool,
  int8: Int8,
  uint16: UInt16,
  int16: Int16,
  int32: Int32,
  int64: Int64,
  _float: Float,
  _double: Double,
  string: String,
  object: MySwiftClass,
  optionalObject: MySwiftClass?
) -> CallbackOutput {
  return CallbackOutput(
    bool: callbacks.withBool(bool),
    int8: callbacks.withInt8(int8),
    uint16: callbacks.withUInt16(uint16),
    int16: callbacks.withInt16(int16),
    int32: callbacks.withInt32(int32),
    int64: callbacks.withInt64(int64),
    _float: callbacks.withFloat(_float),
    _double: callbacks.withDouble(_double),
    string: callbacks.withString(string),
    object: callbacks.withObject(object),
    optionalObject: callbacks.withOptionalObject(optionalObject)
  )
}
