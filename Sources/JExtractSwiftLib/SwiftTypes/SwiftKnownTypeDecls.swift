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

import SwiftSyntax

enum SwiftKnownType {
  case bool
  case int
  case uint
  case int8
  case uint8
  case int16
  case uint16
  case int32
  case uint32
  case int64
  case uint64
  case float
  case double
  case unsafeRawPointer
  case unsafeRawBufferPointer
  case unsafeMutableRawPointer
  case unsafeMutableRawBufferPointer
  case unsafePointer(_ pointee: SwiftType)
  case unsafeMutablePointer(_ pointee: SwiftType)
  case unsafeBufferPointer(_ element: SwiftType)
  case unsafeMutableBufferPointer(_ element: SwiftType)
  case optional(_ wrapped: SwiftType)
  case void
  case string
  case array(_ element: SwiftType)
  case dictionary(_ key: SwiftType, _ value: SwiftType)
  case set(_ element: SwiftType)

  // Foundation
  case foundationDataProtocol
  case essentialsDataProtocol
  case foundationData
  case essentialsData
  case foundationDate
  case essentialsDate
  case foundationUUID
  case essentialsUUID
}

enum SwiftKnownTypeDeclKind: String, Hashable {
  // Swift
  case bool = "Swift.Bool"
  case int = "Swift.Int"
  case uint = "Swift.UInt"
  case int8 = "Swift.Int8"
  case uint8 = "Swift.UInt8"
  case int16 = "Swift.Int16"
  case uint16 = "Swift.UInt16"
  case int32 = "Swift.Int32"
  case uint32 = "Swift.UInt32"
  case int64 = "Swift.Int64"
  case uint64 = "Swift.UInt64"
  case float = "Swift.Float"
  case double = "Swift.Double"
  case unsafeRawPointer = "Swift.UnsafeRawPointer"
  case unsafeRawBufferPointer = "Swift.UnsafeRawBufferPointer"
  case unsafeMutableRawPointer = "Swift.UnsafeMutableRawPointer"
  case unsafeMutableRawBufferPointer = "Swift.UnsafeMutableRawBufferPointer"
  case unsafePointer = "Swift.UnsafePointer"
  case unsafeMutablePointer = "Swift.UnsafeMutablePointer"
  case unsafeBufferPointer = "Swift.UnsafeBufferPointer"
  case unsafeMutableBufferPointer = "Swift.UnsafeMutableBufferPointer"
  case optional = "Swift.Optional"
  case void = "Swift.Void"
  case string = "Swift.String"
  case array = "Swift.Array"
  case dictionary = "Swift.Dictionary"
  case set = "Swift.Set"

  // Foundation
  case foundationDataProtocol = "Foundation.DataProtocol"
  case essentialsDataProtocol = "FoundationEssentials.DataProtocol"
  case foundationData = "Foundation.Data"
  case essentialsData = "FoundationEssentials.Data"
  case foundationDate = "Foundation.Date"
  case essentialsDate = "FoundationEssentials.Date"
  case foundationUUID = "Foundation.UUID"
  case essentialsUUID = "FoundationEssentials.UUID"

  var moduleAndName: (module: String, name: String) {
    let qualified = self.rawValue
    let period = qualified.firstIndex(of: ".")!
    return (
      module: String(qualified[..<period]),
      name: String(qualified[qualified.index(after: period)...])
    )
  }

  var isPointer: Bool {
    switch self {
    case .unsafePointer, .unsafeMutablePointer, .unsafeRawPointer, .unsafeMutableRawPointer:
      return true
    default:
      return false
    }
  }

  /// Indicates whether this known type is translated by `wrap-java`
  /// into the same type as `jextract`.
  ///
  /// This means we do not have to perform any mapping when passing
  /// this type between jextract and wrap-java
  var isDirectlyTranslatedToWrapJava: Bool {
    switch self {
    case .bool, .int, .uint, .int8, .uint8, .int16, .uint16, .int32, .uint32, .int64, .uint64, .float, .double, .string,
      .void:
      return true
    default:
      return false
    }
  }
}
