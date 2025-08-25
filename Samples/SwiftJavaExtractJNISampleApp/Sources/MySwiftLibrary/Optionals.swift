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

public func optionalBool(input: Optional<Bool>) -> Bool? {
  return input
}

public func optionalByte(input: Optional<Int8>) -> Int8? {
  return input
}

public func optionalChar(input: Optional<UInt16>) -> UInt16? {
  return input
}

public func optionalShort(input: Optional<Int16>) -> Int16? {
  return input
}

public func optionalInt(input: Optional<Int32>) -> Int32? {
  return input
}

public func optionalLong(input: Optional<Int64>) -> Int64? {
  return input
}

public func optionalFloat(input: Optional<Float>) -> Float? {
  return input
}

public func optionalDouble(input: Optional<Double>) -> Double? {
  return input
}

public func optionalString(input: Optional<String>) -> String? {
  return input
}

public func optionalClass(input: Optional<MySwiftClass>) -> MySwiftClass? {
  return input
}

public func optionalJavaKitLong(input: Optional<JavaLong>) -> Int64? {
  if let input {
    return input.longValue()
  } else {
    return nil
  }
}

public func multipleOptionals(
  input1: Optional<Int8>,
  input2: Optional<Int16>,
  input3: Optional<Int32>,
  input4: Optional<Int64>,
  input5: Optional<String>,
  input6: Optional<MySwiftClass>,
  input7: Optional<Bool>
) -> Int64? {
  return 1
}
