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

#ifndef CSwiftJavaJNI_h
#define CSwiftJavaJNI_h

#include <jni.h>

// Provide C-compatible type aliases for JNI types.
// When Swift modules have C++ interoperability enabled, jni.h is parsed
// in C++ mode where JNIEnv is defined as a struct (JNIEnv_). However,
// SwiftJava modules are compiled without C++ interop, causing JNIEnv
// to be a pointer type. This mismatch causes type errors.
//
// These typedefs provide consistent C-style pointer types that work
// regardless of the C++ interoperability mode.
// See: https://github.com/swiftlang/swift-java/issues/391
#ifdef __cplusplus
typedef const struct JNINativeInterface_ *CJNIEnv;
typedef _jobject *Cjobject;
typedef _jclass *Cjclass;
typedef _jstring *Cjstring;
typedef _jarray *Cjarray;
typedef _jobjectArray *CjobjectArray;
typedef _jbooleanArray *CjbooleanArray;
typedef _jbyteArray *CjbyteArray;
typedef _jcharArray *CjcharArray;
typedef _jshortArray *CjshortArray;
typedef _jintArray *CjintArray;
typedef _jlongArray *CjlongArray;
typedef _jfloatArray *CjfloatArray;
typedef _jdoubleArray *CjdoubleArray;
typedef _jthrowable *Cjthrowable;
#else
typedef JNIEnv CJNIEnv;
typedef jobject Cjobject;
typedef jclass Cjclass;
typedef jstring Cjstring;
typedef jarray Cjarray;
typedef jobjectArray CjobjectArray;
typedef jbooleanArray CjbooleanArray;
typedef jbyteArray CjbyteArray;
typedef jcharArray CjcharArray;
typedef jshortArray CjshortArray;
typedef jintArray CjintArray;
typedef jlongArray CjlongArray;
typedef jfloatArray CjfloatArray;
typedef jdoubleArray CjdoubleArray;
typedef jthrowable Cjthrowable;
#endif

#endif /* CSwiftJavaJNI_h */
