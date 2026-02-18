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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public func optionalBool(input: Bool?) -> Bool? {
  input
}

public func optionalByte(input: Int8?) -> Int8? {
  input
}

public func optionalChar(input: UInt16?) -> UInt16? {
  input
}

public func optionalShort(input: Int16?) -> Int16? {
  input
}

public func optionalInt(input: Int32?) -> Int32? {
  input
}

public func optionalLong(input: Int64?) -> Int64? {
  input
}

public func optionalFloat(input: Float?) -> Float? {
  input
}

public func optionalDouble(input: Double?) -> Double? {
  input
}

public func optionalString(input: String?) -> String? {
  input
}

public func optionalClass(input: MySwiftClass?) -> MySwiftClass? {
  input
}

public func optionalDate(input: Date?) -> Date? {
  input
}

public func optionalData(input: Data?) -> Data? {
  input
}

public func optionalJavaKitLong(input: JavaLong?) -> Int64? {
  if let input {
    return input.longValue()
  } else {
    return nil
  }
}

public func optionalThrowing() throws -> Int64? {
  throw MySwiftError.swiftError
}

public func multipleOptionals(
  input1: Int8?,
  input2: Int16?,
  input3: Int32?,
  input4: Int64?,
  input5: String?,
  input6: MySwiftClass?,
  input7: Bool?
) -> Int64? {
  1
}
