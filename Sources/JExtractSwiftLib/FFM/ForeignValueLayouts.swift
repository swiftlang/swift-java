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

/// Represents a value of a `java.lang.foreign.Self` that we want to render in generated Java code.
///
/// This type may gain further methods for adjusting target layout, byte order, names etc.
public struct ForeignValueLayout: CustomStringConvertible, Equatable {
  var inlineComment: String?
  var value: String

  public init(inlineComment: String? = nil, javaConstant: String) {
    self.inlineComment = inlineComment
    self.value = "SwiftValueLayout.\(javaConstant)"
  }

  public init(inlineComment: String? = nil, customType: String) {
    self.inlineComment = inlineComment
    // When the type is some custom type, e.g. another Swift struct that we imported,
    // we need to import its layout. We do this by referring $LAYOUT on it.
    self.value = "\(customType).$LAYOUT"
  }

  public init?(javaType: JavaType) {
    switch javaType {
    case .boolean: self = .SwiftBool
    case .byte: self =  .SwiftInt8
    case .char: self =  .SwiftUInt16
    case .short: self =  .SwiftInt16
    case .int: self =  .SwiftInt32
    case .long: self =  .SwiftInt64
    case .float: self =  .SwiftFloat
    case .double: self =  .SwiftDouble
    case .javaForeignMemorySegment: self = .SwiftPointer
    case .array, .class, .void: return nil
    }
  }

  public var description: String {
    var result = ""

    if let inlineComment {
      result.append("/*\(inlineComment)*/")
    }

    result.append(value)

    return result
  }
}

extension ForeignValueLayout {
  public static let SwiftPointer = Self(javaConstant: "SWIFT_POINTER")

  public static let SwiftBool = Self(javaConstant: "SWIFT_BOOL")

  public static let SwiftInt = Self(javaConstant: "SWIFT_INT")
  public static let SwiftUInt = Self(javaConstant: "SWIFT_UINT")

  public static let SwiftInt64 = Self(javaConstant: "SWIFT_INT64")
  public static let SwiftUInt64 = Self(javaConstant: "SWIFT_UINT64")

  public static let SwiftInt32 = Self(javaConstant: "SWIFT_INT32")
  public static let SwiftUInt32 = Self(javaConstant: "SWIFT_UINT32")

  public static let SwiftInt16 = Self(javaConstant: "SWIFT_INT16")
  public static let SwiftUInt16 = Self(javaConstant: "SWIFT_UINT16")

  public static let SwiftInt8 = Self(javaConstant: "SWIFT_INT8")
  public static let SwiftUInt8 = Self(javaConstant: "SWIFT_UINT8")

  public static let SwiftFloat = Self(javaConstant: "SWIFT_FLOAT")
  public static let SwiftDouble = Self(javaConstant: "SWIFT_DOUBLE")
}
