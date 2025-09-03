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
  public func isSwiftOptional(stringIsValueType: Bool) -> Bool {
    switch self {
    case .boolean, .byte, .char, .short, .int, .long, .float, .double, .void,
      .array:
      return false

    case .class(package: "java.lang", name: "String"):
      return !stringIsValueType

    case .class:
      return true
    }
  }

  public var isSwiftClosure: Bool {
    switch self {
    case .boolean, .byte, .char, .short, .int, .long, .float, .double, .void,
         .array:
      return false
    case .class(package: "java.lang", name: "Runnable"):
      return true
    case .class:
      return false
    }
  }

  public var isVoid: Bool {
    if case .void = self {
      return true
    }
    return false
  }

  public var isString: Bool {
    switch self {
    case .boolean, .byte, .char, .short, .int, .long, .float, .double, .void,
         .array:
      return false
    case .class(package: "java.lang", name: "String"):
      return true
    case .class:
      return false
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
      let elementIsOptional = elementType.isSwiftOptional(stringIsValueType: true)
      return "[\(elementTypeName)\(elementIsOptional ? "?" : "")]"

    case .class: return try resolver(description)
    }
  }

}
