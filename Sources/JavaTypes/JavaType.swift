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

/// Describes the Java type system.
public enum JavaType: Equatable, Hashable {
  case boolean
  case byte
  case char
  case short
  case int
  case long
  case float
  case double
  case void

  /// A Java class separated into its package (e.g., "java.lang") and class name
  /// (e.g., "Object")
  case `class`(package: String?, name: String)

  /// A Java array.
  indirect case array(JavaType)

  /// Given a canonical class name such as "java.lang.Object", split it into
  /// its package and class name to form a class instance.
  public init(canonicalClassName name: some StringProtocol) {
    if let lastDot = name.lastIndex(of: ".") {
      self = .class(
        package: String(name[..<lastDot]),
        name: String(name[name.index(after: lastDot)...])
      )
    } else {
      self = .class(package: nil, name: String(name))
    }
  }
}

extension JavaType {
  /// Whether this is a primitive Java type.
  public var isPrimitive: Bool {
    switch self {
    case .boolean, .byte, .char, .short, .int, .long, .float, .double, .void:
      true

    case .class, .array:
      false
    }
  }
}
