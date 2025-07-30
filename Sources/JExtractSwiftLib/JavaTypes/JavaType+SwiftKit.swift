//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaTypes

extension JavaType {

  /// Try to map a Swift type name (e.g., from the module Swift) over to a
  /// primitive Java type, or fail otherwise.
  public init?(swiftTypeName: String, unsigned: UnsignedNumericsMode) {
    switch swiftTypeName {
    case "Bool": self = .boolean

    case "Int8": self = .byte
    case "UInt8":
      self = switch unsigned {
        case .ignoreSign: .char
        case .wrapUnsignedGuava: JavaType.guava.primitives.UnsignedInteger
      }

    case "Int16": self = .short
    case "UInt16": self = .char

    case "Int32": self = .int
    case "UInt32":
      self = switch unsigned {
      case .ignoreSign: .int
      case .wrapUnsignedGuava: JavaType.guava.primitives.UnsignedInteger
      }

    case "Int64": self = .long
    case "UInt64":
      self = switch unsigned {
      case .ignoreSign: .long
      case .wrapUnsignedGuava: JavaType.guava.primitives.UnsignedLong
      }

    case "Float": self = .float
    case "Double": self = .double
    case "Void": self = .void
    default: return nil
    }
  }
}

extension JavaType {

  static func unsignedWrapper(for swiftType: SwiftType) -> JavaType? {
    switch swiftType {
    case .nominal(let nominal):
      switch nominal.nominalTypeDecl.knownTypeKind {
      case .uint8: return guava.primitives.UnsignedInteger
      case .uint16: return .char // no wrapper necessary, we can express it as 'char' natively in Java
      case .uint32: return guava.primitives.UnsignedInteger
      case .uint64: return guava.primitives.UnsignedLong
      default: return nil
      }
    default: return nil
    }
  }

  /// Known types from the Google Guava library
  enum guava {
    enum primitives {
      static let package = "com.google.common.primitives"

      static var UnsignedInteger: JavaType {
        .class(package: primitives.package, name: "UnsignedInteger")
      }

      static var UnsignedLong: JavaType {
        .class(package: primitives.package, name: "UnsignedLong")
      }
    }
  }

}
