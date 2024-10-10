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

/// The type of a resolver function that turns a canonical Java class name into
/// the corresponding Swift type name. If there is no such Swift type, the
/// resolver can throw an error to indicate the problem.
public typealias JavaToSwiftClassNameResolver = (String) throws -> String

extension JavaType {
  /// Whether this Java type needs to be represented by a Swift optional.
  public var isSwiftOptional: Bool {
    switch self {
    case .boolean, .byte, .char, .short, .int, .long, .float, .double, .void,
      .array, .class(package: "java.lang", name: "String"):
      return false

    case .class:
      return true
    }
  }

  /// Produce the Swift type name for this Java type.
  public func swiftTypeName(resolver: JavaToSwiftClassNameResolver) rethrows -> String {
    switch self {
    case .boolean: return "Bool"
    case .byte: return "Int8"
    case .char: return "UInt16"
    case .short: return "Int16"
    case .int: return "Int32"
    case .long: return "Int64"
    case .float: return "Float"
    case .double: return "Double"
    case .void: return "Void"
    case .array(let elementType):
      let elementTypeName = try elementType.swiftTypeName(resolver: resolver)
      let elementIsOptional = elementType.isSwiftOptional
      return "[\(elementTypeName)\(elementIsOptional ? "?" : "")]"

    case .class: return try resolver(description)
    }
  }

  /// Try to map a Swift type name (e.g., from the module Swift) over to a
  /// primitive Java type, or fail otherwise.
  public init?(swiftTypeName: String) {
    switch swiftTypeName {
    case "Bool": self = .boolean
    case "Int8": self = .byte
    case "UInt16": self = .char
    case "Int16": self = .short
    case "Int32": self = .int
    case "Int64": self = .long
    case "Float": self = .float
    case "Double": self = .double
    case "Void": self = .void
    default: return nil
    }
  }
}
