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

/// Represents types that are able to be passed over a JNI boundary.
///
/// - SeeAlso: https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/types.html
enum JNIType {
  case jboolean
  case jfloat
  case jdouble
  case jbyte
  case jchar
  case jshort
  case jint
  case jlong
  case void
  case jstring
  case jclass
  case jthrowable
  case jobject
  case jbooleanArray
  case jbyteArray
  case jcharArray
  case jshortArray
  case jintArray
  case jlongArray
  case jfloatArray
  case jdoubleArray
  case jobjectArray

  var callMethodAName: String {
    switch self {
    case .jboolean: "CallBooleanMethodA"
    case .jbyte: "CallByteMethodA"
    case .jchar: "CallCharMethodA"
    case .jshort: "CallShortMethodA"
    case .jint: "CallIntMethodA"
    case .jlong: "CallLongMethodA"
    case .jfloat: "CallFloatMethodA"
    case .jdouble: "CallDoubleMethodA"
    case .void: "CallVoidMethodA"
    case .jobject, .jstring, .jclass, .jthrowable: "CallObjectMethodA"
    case .jbooleanArray, .jbyteArray, .jcharArray, .jshortArray, .jintArray, .jlongArray, .jfloatArray, .jdoubleArray, .jobjectArray: "CallObjectMethodA"
    }
  }
}

extension JavaType {
  var jniType: JNIType {
    switch self {
    case .boolean: .jboolean
    case .byte: .jbyte
    case .char: .jchar
    case .short: .jshort
    case .int: .jint
    case .long: .jlong
    case .float: .jfloat
    case .double: .jdouble
    case .void: .void
    case .array(.boolean): .jbooleanArray
    case .array(.byte): .jbyteArray
    case .array(.char): .jcharArray
    case .array(.short): .jshortArray
    case .array(.int): .jintArray
    case .array(.long): .jlongArray
    case .array(.float): .jfloatArray
    case .array(.double): .jdoubleArray
    case .array: .jobjectArray
    case .javaLangString: .jstring
    case .javaLangClass: .jclass
    case .javaLangThrowable: .jthrowable
    case .class: .jobject
    }
  }

  /// Returns whether this type returns `JavaValue` from JavaKit
  var implementsJavaValue: Bool {
    return switch self {
    case .boolean, .byte, .char, .short, .int, .long, .float, .double, .void, .javaLangString:
      true
    default:
      false
    }
  }
}
