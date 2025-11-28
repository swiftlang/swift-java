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
  /// Map this Java type to the appropriate JNI type name.
  /// Uses C-compatible types (Cjobject, Cjstring, etc.) for C++ interoperability.
  /// See: https://github.com/swiftlang/swift-java/issues/391
  package var jniTypeName: String {
    switch self {
    case .boolean: "jboolean"
    case .float: "jfloat"
    case .double: "jdouble"
    case .byte: "jbyte"
    case .char: "jchar"
    case .short: "jshort"
    case .int: "jint"
    case .long: "jlong"
    case .void: "void"
    case .array(.boolean): "CjbooleanArray?"
    case .array(.byte): "CjbyteArray?"
    case .array(.char): "CjcharArray?"
    case .array(.short): "CjshortArray?"
    case .array(.int): "CjintArray?"
    case .array(.long): "CjlongArray?"
    case .array(.float): "CjfloatArray?"
    case .array(.double): "CjdoubleArray?"
    case .array: "CjobjectArray?"
    case .class(package: "java.lang", name: "String", _): "Cjstring?"
    case .class(package: "java.lang", name: "Class", _): "Cjclass?"
    case .class(package: "java.lang", name: "Throwable", _): "Cjthrowable?"
    case .class: "Cjobject?"
    }
  }

  /// Map this Java type to the appropriate JNI field name within the 'jvalue'
  /// union.
  public var jniFieldName: String {
    switch self {
    case .boolean: "z"
    case .byte: "b"
    case .char: "c"
    case .short: "s"
    case .int: "i"
    case .long: "j"
    case .float: "f"
    case .double: "d"
    case .class, .array: "l"
    case .void: fatalError("There is no field name for 'void'")
    }
  }
}
