//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import CSwiftJavaJNI
import SwiftJavaJNICore

/// JNI reference and value types as imported by the runtime in C mode.
///
/// Use these aliases in generated code so C++-enabled consumers share the
/// runtime's types instead of importing Android's C++ JNI wrapper types.
public enum JNITypes {
  public typealias jobject = CSwiftJavaJNI.jobject
  public typealias jclass = CSwiftJavaJNI.jclass
  public typealias jstring = CSwiftJavaJNI.jstring
  public typealias jarray = CSwiftJavaJNI.jarray
  public typealias jobjectArray = CSwiftJavaJNI.jobjectArray
  public typealias jbooleanArray = CSwiftJavaJNI.jbooleanArray
  public typealias jbyteArray = CSwiftJavaJNI.jbyteArray
  public typealias jcharArray = CSwiftJavaJNI.jcharArray
  public typealias jshortArray = CSwiftJavaJNI.jshortArray
  public typealias jintArray = CSwiftJavaJNI.jintArray
  public typealias jlongArray = CSwiftJavaJNI.jlongArray
  public typealias jfloatArray = CSwiftJavaJNI.jfloatArray
  public typealias jdoubleArray = CSwiftJavaJNI.jdoubleArray
  public typealias jthrowable = CSwiftJavaJNI.jthrowable
  public typealias jweak = CSwiftJavaJNI.jweak
  public typealias jvalue = CSwiftJavaJNI.jvalue

  /// Construct the union in C mode, where its object field uses the runtime's type.
  public static func objectValue(_ object: jobject?) -> jvalue {
    jvalue(l: object)
  }
}

/// The JNI operations used by generated code, with signatures fixed in C mode.
///
/// Reading fields of the imported C function table directly in a C++ consumer
/// reimports their signatures with the NDK's C++ JNI types. These Swift getters
/// keep both sides of each call in the runtime's C import context.
public struct JNIInterface {
  fileprivate let environment: JNIEnvironment

  public var GetObjectClass: @convention(c) (JNIEnvironment?, jobject?) -> jclass? {
    environment.interface.GetObjectClass
  }

  public var GetMethodID: @convention(c) (JNIEnvironment?, jclass?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> jmethodID? {
    environment.interface.GetMethodID
  }

  public var IsInstanceOf: @convention(c) (JNIEnvironment?, jobject?, jclass?) -> jboolean {
    environment.interface.IsInstanceOf
  }

  public var NewGlobalRef: @convention(c) (JNIEnvironment?, jobject?) -> jobject? {
    environment.interface.NewGlobalRef
  }

  public var DeleteGlobalRef: @convention(c) (JNIEnvironment?, jobject?) -> Void {
    environment.interface.DeleteGlobalRef
  }

  public var DeleteLocalRef: @convention(c) (JNIEnvironment?, jobject?) -> Void {
    environment.interface.DeleteLocalRef
  }

  public var NewObjectA: @convention(c) (JNIEnvironment?, jclass?, jmethodID?, UnsafePointer<jvalue>?) -> jobject? {
    environment.interface.NewObjectA
  }

  public var SetLongField: @convention(c) (JNIEnvironment?, jobject?, jfieldID?, jlong) -> Void {
    environment.interface.SetLongField
  }

  public var GetArrayLength: @convention(c) (JNIEnvironment?, jarray?) -> jsize {
    environment.interface.GetArrayLength
  }

  public var GetByteArrayElements: @convention(c) (JNIEnvironment?, jbyteArray?, UnsafeMutablePointer<jboolean>?) -> UnsafeMutablePointer<jbyte>? {
    environment.interface.GetByteArrayElements
  }

  public var ReleaseByteArrayElements: @convention(c) (JNIEnvironment?, jbyteArray?, UnsafeMutablePointer<jbyte>?, jint) -> Void {
    environment.interface.ReleaseByteArrayElements
  }

  public var SetObjectArrayElement: @convention(c) (JNIEnvironment?, jobjectArray?, jsize, jobject?) -> Void {
    environment.interface.SetObjectArrayElement
  }

  public var CallObjectMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jobject? {
    environment.interface.CallObjectMethodA
  }

  public var CallBooleanMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jboolean {
    environment.interface.CallBooleanMethodA
  }

  public var CallByteMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jbyte {
    environment.interface.CallByteMethodA
  }

  public var CallCharMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jchar {
    environment.interface.CallCharMethodA
  }

  public var CallShortMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jshort {
    environment.interface.CallShortMethodA
  }

  public var CallIntMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jint {
    environment.interface.CallIntMethodA
  }

  public var CallLongMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jlong {
    environment.interface.CallLongMethodA
  }

  public var CallFloatMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jfloat {
    environment.interface.CallFloatMethodA
  }

  public var CallDoubleMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> jdouble {
    environment.interface.CallDoubleMethodA
  }

  public var CallVoidMethodA: @convention(c) (JNIEnvironment?, jobject?, jmethodID?, UnsafePointer<jvalue>?) -> Void {
    environment.interface.CallVoidMethodA
  }

  public var SetBooleanArrayRegion: @convention(c) (JNIEnvironment?, jbooleanArray?, jsize, jsize, UnsafePointer<jboolean>?) -> Void {
    environment.interface.SetBooleanArrayRegion
  }

  public var SetByteArrayRegion: @convention(c) (JNIEnvironment?, jbyteArray?, jsize, jsize, UnsafePointer<jbyte>?) -> Void {
    environment.interface.SetByteArrayRegion
  }

  public var SetCharArrayRegion: @convention(c) (JNIEnvironment?, jcharArray?, jsize, jsize, UnsafePointer<jchar>?) -> Void {
    environment.interface.SetCharArrayRegion
  }

  public var SetShortArrayRegion: @convention(c) (JNIEnvironment?, jshortArray?, jsize, jsize, UnsafePointer<jshort>?) -> Void {
    environment.interface.SetShortArrayRegion
  }

  public var SetIntArrayRegion: @convention(c) (JNIEnvironment?, jintArray?, jsize, jsize, UnsafePointer<jint>?) -> Void {
    environment.interface.SetIntArrayRegion
  }

  public var SetLongArrayRegion: @convention(c) (JNIEnvironment?, jlongArray?, jsize, jsize, UnsafePointer<jlong>?) -> Void {
    environment.interface.SetLongArrayRegion
  }

  public var SetFloatArrayRegion: @convention(c) (JNIEnvironment?, jfloatArray?, jsize, jsize, UnsafePointer<jfloat>?) -> Void {
    environment.interface.SetFloatArrayRegion
  }

  public var SetDoubleArrayRegion: @convention(c) (JNIEnvironment?, jdoubleArray?, jsize, jsize, UnsafePointer<jdouble>?) -> Void {
    environment.interface.SetDoubleArrayRegion
  }
}

extension JNIEnvironment {
  public var swiftInterface: JNIInterface {
    JNIInterface(environment: self)
  }
}
