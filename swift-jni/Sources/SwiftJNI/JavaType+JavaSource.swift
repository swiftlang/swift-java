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

extension JavaType {
  /// Form a Java type based on the name that is produced by
  /// java.lang.Class.getName(). This can be primitive types like "int",
  /// class types like "java.lang.String", or arrays thereof.
  public init(javaTypeName: String) throws {
    switch javaTypeName {
    case "boolean": self = .boolean
    case "byte": self = .byte
    case "char": self = .char
    case "short": self = .short
    case "int": self = .int
    case "long": self = .long
    case "float": self = .float
    case "double": self = .double
    case "void": self = .void

    case let name where name.starts(with: "["):
      self = try JavaType(mangledName: name)

    case let className:
      self = JavaType(className: className)
    }
  }
}

extension JavaType: CustomStringConvertible {
  /// Description of the Java type as it would appear in Java source.
  public var description: String {
    switch self {
    case .boolean: "boolean"
    case .byte: "byte"
    case .char: "char"
    case .short: "short"
    case .int: "int"
    case .long: "long"
    case .float: "float"
    case .double: "double"
    case .void: "void"
    case .array(let elementType): "\(elementType.description)[]"
    case .class(package: let package, name: let name):
      if let package {
        "\(package).\(name)"
      } else {
        name
      }
    }
  }

  /// Returns the class name if this java type was a class,
  /// and nil otherwise.
  public var className: String? {
    switch self {
    case .class(_, let name):
      return name
    default:
      return nil
    }
  }

  /// Returns the fully qualified class name if this java type was a class,
  /// and nil otherwise.
  public var fullyQualifiedClassName: String? {
    switch self {
    case .class(.some(let package), let name):
      return "\(package).\(name)"
    case .class(nil, let name):
      return name
    default:
      return nil
    }
  }
}
