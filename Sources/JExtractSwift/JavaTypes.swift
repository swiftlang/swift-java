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
  /// The description of the type java.lang.foreign.MemorySegment.
  static var javaForeignMemorySegment: JavaType {
    .class(package: "java.lang.foreign", name: "MemorySegment")
  }

  /// The description of the type java.lang.Runnable.
  static var javaLangRunnable: JavaType {
    .class(package: "java.lang", name: "Runnable")
  }
}

// ==== ------------------------------------------------------------------------
// Optionals

extension JavaType {

  static var javaUtilOptionalInt: JavaType {
    .class(package: "java.util", name: "OptionalInt")
  }

  static var javaUtilOptionalLong: JavaType {
    .class(package: "java.util", name: "OptionalLong")
  }

  static var javaUtilOptionalDouble: JavaType {
    .class(package: "java.util", name: "OptionalDouble")
  }

  // FIXME: general generics?
  static func javaUtilOptionalT(_ javaType: JavaType) -> JavaType {
    if let className = javaType.className {
      return .class(package: "java.util", name: "Optional<\(className)>")
    }

    if javaType.isPrimitive {
      switch javaType {
      case .int, .long:
        return .javaUtilOptionalLong
      case .float, .double:
        return .javaUtilOptionalDouble
      case .boolean:
        return .class(package: "java.util", name: "Optional<Boolean>")
      case .byte:
        return .class(package: "java.util", name: "Optional<Byte>")
      case .char:
        return .class(package: "java.util", name: "Optional<Character>")
      case .short:
        return .class(package: "java.util", name: "Optional<Short>")
      case .void:
        return .class(package: "java.util", name: "Optional<Void>")
      default:
        fatalError("Impossible type to map to Optional: \(javaType)")
      }
    }

    fatalError("Impossible type to map to Optional: \(javaType)")
  }
}
