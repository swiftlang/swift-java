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

// Force C-mode JNI type definitions to ensure compatibility with
// Swift modules that have C++ interoperability enabled.
// In C++ mode, jni.h defines JNIEnv as a struct (JNIEnv_), but in C mode
// it's defined as a pointer (const struct JNINativeInterface_*).
// This inconsistency causes type mismatches when mixing modules with
// different interoperability settings.
// See: https://github.com/swiftlang/swift-java/issues/391
#ifdef __cplusplus
#pragma push_macro("__cplusplus")
#undef __cplusplus
#define CSWIFTJAVAJNI_RESTORE_CPLUSPLUS
#endif

#include <jni.h>

#ifdef CSWIFTJAVAJNI_RESTORE_CPLUSPLUS
#pragma pop_macro("__cplusplus")
#undef CSWIFTJAVAJNI_RESTORE_CPLUSPLUS
#endif

#endif /* CSwiftJavaJNI_h */
