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

import SwiftJNI

extension JavaType {

  /// Try to map a Swift type name (e.g., from the module Swift) over to a
  /// primitive Java type, or fail otherwise.
  public init?(swiftTypeName: String, WHT_unsigned unsigned: UnsignedNumericsMode) {
    switch swiftTypeName {
    case "Bool": self = .boolean

    case "Int8": self = .byte
    case "UInt8":
      self = switch unsigned {
        case .ignoreSign: .byte
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

/// Determines how type conversion should deal with Swift's unsigned numeric types.
///
/// When `ignoreSign` is used, unsigned Swift types are imported directly as their corresponding bit-width types,
/// which may yield surprising values when an unsigned Swift value is interpreted as a signed Java type:
/// - `UInt8` is imported as `byte`
/// - `UInt16` is imported as `char` (this is always correct, since `char` is unsigned in Java)
/// - `UInt32` is imported as `int`
/// - `UInt64` is imported as `long`
///
/// When `wrapUnsignedGuava` is used, unsigned Swift types are imported as safe "wrapper" types from the popular Guava
/// library on the Java side. SwiftJava does not include these types, so you would have to make sure your project depends
/// on Guava for such generated code to be able to compile.
///
/// These make the Unsigned nature of the types explicit in Java, however they come at a cost of allocating the wrapper
/// object, and indirection when accessing the underlying numeric value. These are often useful as a signal to watch out
/// when dealing with a specific API, however in high performance use-cases, one may want to choose using the primitive
///  values directly, and interact with them using {@code UnsignedIntegers} SwiftKit helper classes on the Java side.
///
/// The type mappings in this mode are as follows:
/// - `UInt8` is imported as `com.google.common.primitives.UnsignedInteger`
/// - `UInt16` is imported as `char` (this is always correct, since `char` is unsigned in Java)
/// - `UInt32` is imported as `com.google.common.primitives.UnsignedInteger`
/// - `UInt64` is imported as `com.google.common.primitives.UnsignedLong`
public enum UnsignedNumericsMode {
  case ignoreSign
  case wrapUnsignedGuava
}
