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
///
/// Some types may need to be annotated when in parameter position,
public enum JavaType: Equatable, Hashable {
  case boolean
  case byte(parameterAnnotations: [JavaAnnotation])
  case char(parameterAnnotations: [JavaAnnotation])
  case short(parameterAnnotations: [JavaAnnotation])
  case int(parameterAnnotations: [JavaAnnotation])
  case long(parameterAnnotations: [JavaAnnotation])
  case float
  case double
  case void

  /// A Java class separated into its package (e.g., "java.lang") and class name
  /// (e.g., "Object")
  case `class`(package: String?, name: String)

  /// A Java array.
  indirect case array(JavaType)

  public static var byte: JavaType { .byte(parameterAnnotations: []) }
  public static var char: JavaType { .char(parameterAnnotations: []) }
  public static var short: JavaType { .short(parameterAnnotations: []) }
  public static var int: JavaType { .int(parameterAnnotations: []) }
  public static var long: JavaType { .long(parameterAnnotations: []) }

  /// Given a class name such as "java.lang.Object", split it into
  /// its package and class name to form a class instance.
  public init(className name: some StringProtocol) {
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
  /// List of Java annotations this type should have include in parameter position,
  /// e.g. `void example(@Unsigned long num)`
  public var parameterAnnotations: [JavaAnnotation] {
    switch self {
    case .byte(let parameterAnnotations): return parameterAnnotations
    case .char(let parameterAnnotations): return parameterAnnotations
    case .short(let parameterAnnotations): return parameterAnnotations
    case .int(let parameterAnnotations): return parameterAnnotations
    case .long(let parameterAnnotations): return parameterAnnotations
    default: return []
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

