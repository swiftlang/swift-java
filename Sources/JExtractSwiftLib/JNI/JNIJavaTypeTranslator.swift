//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJavaConfigurationShared
import SwiftJavaJNICore

enum JNIJavaTypeTranslator {

  static func translate(knownType: SwiftKnownTypeDeclKind, config: Configuration) -> JavaType? {
    switch knownType {
    case .bool: return .boolean

    case .int8: return .byte
    case .uint8: return .byte

    case .int16: return .short
    case .uint16: return .char

    case .int32: return .int
    case .uint32: return .int

    case .int64: return .long
    case .uint64: return .long

    case .int, .uint: return .long

    case .float: return .float
    case .double: return .double
    case .void: return .void

    case .string: return .javaLangString

    case .unsafeRawPointer, .unsafeMutableRawPointer,
      .unsafePointer, .unsafeMutablePointer,
      .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer,
      .unsafeBufferPointer, .unsafeMutableBufferPointer,
      .optional,
      .foundationData, .foundationDataProtocol,
      .essentialsData, .essentialsDataProtocol,
      .array,
      .dictionary,
      .set,
      .foundationDate, .essentialsDate,
      .foundationUUID, .essentialsUUID,
      .swiftJavaError:
      return nil
    }
  }

  static func checkStep(
    parameterType: SwiftKnownTypeDeclKind,
    parameterName: String,
    from knownTypes: SwiftKnownTypes
  ) -> JNISwift2JavaGenerator.NativeSwiftConversionCheck? {
    switch parameterType {
    case .int: .check32BitIntOverflow(parameterName: parameterName, typeWithMinAndMax: knownTypes.int32)
    case .uint: .check32BitIntOverflow(parameterName: parameterName, typeWithMinAndMax: knownTypes.uint32)

    case .bool, .int8, .uint8, .int16, .uint16, .int32, .uint32, .int64, .uint64,
      .float, .double, .void, .string,
      .unsafeRawPointer, .unsafeMutableRawPointer,
      .unsafePointer, .unsafeMutablePointer,
      .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer,
      .unsafeBufferPointer, .unsafeMutableBufferPointer,
      .optional,
      .foundationData, .foundationDataProtocol,
      .essentialsData, .essentialsDataProtocol,
      .array,
      .dictionary,
      .set,
      .foundationDate, .essentialsDate,
      .foundationUUID, .essentialsUUID,
      .swiftJavaError:
      nil
    }
  }
}
