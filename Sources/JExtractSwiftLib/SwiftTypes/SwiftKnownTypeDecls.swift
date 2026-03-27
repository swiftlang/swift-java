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

enum SwiftKnownType: Equatable {
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

  init?(kind: SwiftKnownTypeDeclKind, genericArguments: [SwiftType]?) {
    switch kind {
    case .bool: self = .bool
    case .int: self = .int
    case .uint: self = .uint
    case .int8: self = .int8
    case .uint8: self = .uint8
    case .int16: self = .int16
    case .uint16: self = .uint16
    case .int32: self = .int32
    case .uint32: self = .uint32
    case .int64: self = .int64
    case .uint64: self = .uint64
    case .float: self = .float
    case .double: self = .double
    case .unsafeRawPointer: self = .unsafeRawPointer
    case .unsafeRawBufferPointer: self = .unsafeRawBufferPointer
    case .unsafeMutableRawPointer: self = .unsafeMutableRawPointer
    case .unsafeMutableRawBufferPointer: self = .unsafeMutableRawBufferPointer
    case .unsafePointer:
      guard let arg = genericArguments?.first else { return nil }
      self = .unsafePointer(arg)
    case .unsafeMutablePointer:
      guard let arg = genericArguments?.first else { return nil }
      self = .unsafeMutablePointer(arg)
    case .unsafeBufferPointer:
      guard let arg = genericArguments?.first else { return nil }
      self = .unsafeBufferPointer(arg)
    case .unsafeMutableBufferPointer:
      guard let arg = genericArguments?.first else { return nil }
      self = .unsafeMutableBufferPointer(arg)
    case .optional:
      guard let arg = genericArguments?.first else { return nil }
      self = .optional(arg)
    case .void: self = .void
    case .string: self = .string
    case .array:
      guard let arg = genericArguments?.first else { return nil }
      self = .array(arg)
    case .dictionary:
      guard let key = genericArguments?.first, let value = genericArguments?.dropFirst().first else { return nil }
      self = .dictionary(key, value)
    case .set:
      guard let arg = genericArguments?.first else { return nil }
      self = .set(arg)
    case .foundationDataProtocol: self = .foundationDataProtocol
    case .essentialsDataProtocol: self = .essentialsDataProtocol
    case .foundationData: self = .foundationData
    case .essentialsData: self = .essentialsData
    case .foundationDate: self = .foundationDate
    case .essentialsDate: self = .essentialsDate
    case .foundationUUID: self = .foundationUUID
    case .essentialsUUID: self = .essentialsUUID
    }
  }

  var kind: SwiftKnownTypeDeclKind {
    switch self {
    case .bool: .bool
    case .int: .int
    case .uint: .uint
    case .int8: .int8
    case .uint8: .uint8
    case .int16: .int16
    case .uint16: .uint16
    case .int32: .int32
    case .uint32: .uint32
    case .int64: .int64
    case .uint64: .uint64
    case .float: .float
    case .double: .double
    case .unsafeRawPointer: .unsafeRawPointer
    case .unsafeRawBufferPointer: .unsafeRawBufferPointer
    case .unsafeMutableRawPointer: .unsafeMutableRawPointer
    case .unsafeMutableRawBufferPointer: .unsafeMutableRawBufferPointer
    case .unsafePointer: .unsafePointer
    case .unsafeMutablePointer: .unsafeMutablePointer
    case .unsafeBufferPointer: .unsafeBufferPointer
    case .unsafeMutableBufferPointer: .unsafeMutableBufferPointer
    case .optional: .optional
    case .void: .void
    case .string: .string
    case .array: .array
    case .dictionary: .dictionary
    case .set: .set
    case .foundationDataProtocol: .foundationDataProtocol
    case .essentialsDataProtocol: .essentialsDataProtocol
    case .foundationData: .foundationData
    case .essentialsData: .essentialsData
    case .foundationDate: .foundationDate
    case .essentialsDate: .essentialsDate
    case .foundationUUID: .foundationUUID
    case .essentialsUUID: .essentialsUUID
    }
  }
}

extension SwiftKnownType {
  var isPointer: Bool {
    switch self {
    case .unsafeRawPointer, .unsafeMutableRawPointer, .unsafePointer, .unsafeMutablePointer:
      return true
    default:
      return false
    }
  }

  var primitiveCType: CType? {
    switch self {
    case .bool: .integral(.bool)
    case .int: .integral(.ptrdiff_t)
    case .uint: .integral(.size_t)
    case .int8: .integral(.signed(bits: 8))
    case .uint8: .integral(.unsigned(bits: 8))
    case .int16: .integral(.signed(bits: 16))
    case .uint16: .integral(.unsigned(bits: 16))
    case .int32: .integral(.signed(bits: 32))
    case .uint32: .integral(.unsigned(bits: 32))
    case .int64: .integral(.signed(bits: 64))
    case .uint64: .integral(.unsigned(bits: 64))
    case .float: .floating(.float)
    case .double: .floating(.double)
    case .unsafeMutableRawPointer: .pointer(.void)
    case .unsafeRawPointer:
      .pointer(
        .qualified(const: true, volatile: false, type: .void)
      )
    case .void: .void
    default:
      nil
    }
  }

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
