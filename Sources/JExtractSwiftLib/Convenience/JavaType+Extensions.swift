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

import JavaTypes

extension JavaType {
  var jniTypeSignature: String {
    switch self {
    case .boolean: return "Z"
    case .byte: return "B"
    case .char: return "C"
    case .short: return "S"
    case .int: return "I"
    case .long: return "J"
    case .float: return "F"
    case .double: return "D"
    case .class(let package, let name, _):
      let nameWithInnerClasses = name.replacingOccurrences(of: ".", with: "$")
      if let package {
        return "L\(package.replacingOccurrences(of: ".", with: "/"))/\(nameWithInnerClasses);"
      } else {
        return "L\(nameWithInnerClasses);"
      }
    case .array(let javaType): return  "[\(javaType.jniTypeSignature)"
    case .void: fatalError("There is no type signature for 'void'")
    }
  }

  /// Returns the next integral type with space for self and an additional byte.
  var nextIntergralTypeWithSpaceForByte: (javaType: JavaType, swiftType: SwiftKnownTypeDeclKind, valueBytes: Int)? {
    switch self {
    case .boolean, .byte: (.short, .int16, 1)
    case .char, .short: (.int, .int32, 2)
    case .int: (.long, .int64, 4)
    default: nil
    }
  }

  var optionalType: String? {
    switch self {
    case .boolean: "Optional<Boolean>"
    case .byte: "Optional<Byte>"
    case .char: "Optional<Character>"
    case .short: "Optional<Short>"
    case .int: "OptionalInt"
    case .long: "OptionalLong"
    case .float: "Optional<Float>"
    case .double: "OptionalDouble"
    case .javaLangString: "Optional<String>"
    default: nil
    }
  }

  var optionalWrapperType: String? {
    switch self {
    case .boolean, .byte, .char, .short, .float, .javaLangString: "Optional"
    case .int: "OptionalInt"
    case .long: "OptionalLong"
    case .double: "OptionalDouble"
    default: nil
    }
  }

  var optionalPlaceholderValue: String? {
    switch self {
    case .boolean: "false"
    case .byte: "(byte) 0"
    case .char: "(char) 0"
    case .short: "(short) 0"
    case .int: "0"
    case .long: "0L"
    case .float: "0f"
    case .double: "0.0"
    case .array, .class: "null"
    case .void: nil
    }
  }

  var jniCallMethodAName: String {
    switch self {
    case .boolean: "CallBooleanMethodA"
    case .byte: "CallByteMethodA"
    case .char: "CallCharMethodA"
    case .short: "CallShortMethodA"
    case .int: "CallIntMethodA"
    case .long: "CallLongMethodA"
    case .float: "CallFloatMethodA"
    case .double: "CallDoubleMethodA"
    case .void: "CallVoidMethodA"
    default: "CallObjectMethodA"
    }
  }

  /// Returns whether this type returns `JavaValue` from SwiftJava
  var implementsJavaValue: Bool {
    return switch self {
    case .boolean, .byte, .char, .short, .int, .long, .float, .double, .void, .javaLangString:
      true
    default:
      false
    }
  }

  /// Returns the boxed type, or self if the type is already a Java class.
  var boxedType: JavaType {
    switch self {
    case .boolean:
      return .class(package: "java.lang", name: "Boolean")
    case .byte:
      return .class(package: "java.lang", name: "Byte")
    case .char:
      return .class(package: "java.lang", name: "Character")
    case .short:
      return .class(package: "java.lang", name: "Short")
    case .int:
      return .class(package: "java.lang", name: "Integer")
    case .long:
      return .class(package: "java.lang", name: "Long")
    case .float:
      return .class(package: "java.lang", name: "Float")
    case .double:
      return .class(package: "java.lang", name: "Double")
    case .void:
      return .class(package: "java.lang", name: "Void")
    default:
      return self
    }
  }

  var requiresBoxing: Bool {
    switch self {
    case .boolean, .byte, .char, .short, .int, .long, .float, .double:
      true
    default:
      false
    }
  }
}
