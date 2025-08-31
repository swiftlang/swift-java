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

import SwiftJNI
import SwiftJavaConfigurationShared

enum JNIJavaTypeTranslator {

  static func translate(knownType: SwiftKnownTypeDeclKind, config: Configuration) -> JavaType? {
    let unsigned = config.effectiveUnsignedNumbersMode
    guard unsigned == .annotate else {
      // We do not support wrap mode in JNI mode currently;
      // In the future this is where it would be interesting to implement Kotlin UInt support.
      return nil
    }

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

    case .float: return .float
    case .double: return .double
    case .void: return .void

    case .string: return .javaLangString
    case .int, .uint, // FIXME: why not supported int/uint?
        .unsafeRawPointer, .unsafeMutableRawPointer,
        .unsafePointer, .unsafeMutablePointer,
        .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer,
        .unsafeBufferPointer, .unsafeMutableBufferPointer,
        .optional, .data, .dataProtocol:
      return nil
    }
  }
}
