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

#ifdef __ANDROID__

#include <JavaRuntime.h>
#include <android/log.h>
#include <dlfcn.h>

// these are not exported by the Android SDK

extern "C" {
  using JavaRuntime_GetDefaultJavaVMInitArgs_fn = jint (*)(void *vm_args);
  using JavaRuntime_CreateJavaVM_fn = jint (*)(JavaVM **, JNIEnv **, void *);
  using JavaRuntime_GetCreatedJavaVMs_fn = jint (*)(JavaVM **, jsize, jsize *);
}

static JavaRuntime_GetDefaultJavaVMInitArgs_fn
    JavaRuntime_GetDefaultJavaVMInitArgs;
static JavaRuntime_CreateJavaVM_fn JavaRuntime_CreateJavaVM;
static JavaRuntime_GetCreatedJavaVMs_fn JavaRuntime_GetCreatedJavaVMs;

static void *JavaRuntime_dlhandle;

__attribute__((constructor)) static void JavaRuntime_init(void) {
  JavaRuntime_dlhandle = dlopen("libnativehelper.so", RTLD_NOW | RTLD_LOCAL);
  if (JavaRuntime_dlhandle == nullptr) {
    __android_log_print(ANDROID_LOG_FATAL, "JavaRuntime",
                        "failed to open libnativehelper.so: %s", dlerror());
    return;
  }

  JavaRuntime_GetDefaultJavaVMInitArgs =
      reinterpret_cast<JavaRuntime_GetDefaultJavaVMInitArgs_fn>(
          dlsym(JavaRuntime_dlhandle, "JNI_GetDefaultJavaVMInitArgs"));
  if (JavaRuntime_GetDefaultJavaVMInitArgs == nullptr)
    __android_log_print(ANDROID_LOG_FATAL, "JavaRuntime",
                        "JNI_GetDefaultJavaVMInitArgs not found: %s",
                        dlerror());

  JavaRuntime_CreateJavaVM = reinterpret_cast<JavaRuntime_CreateJavaVM_fn>(
      dlsym(JavaRuntime_dlhandle, "JNI_CreateJavaVM"));
  if (JavaRuntime_CreateJavaVM == nullptr)
    __android_log_print(ANDROID_LOG_FATAL, "JavaRuntime",
                        "JNI_CreateJavaVM not found: %s", dlerror());

  JavaRuntime_GetCreatedJavaVMs =
      reinterpret_cast<JavaRuntime_GetCreatedJavaVMs_fn>(
          dlsym(JavaRuntime_dlhandle, "JNI_GetCreatedJavaVMs"));
  if (JavaRuntime_GetCreatedJavaVMs == nullptr)
    __android_log_print(ANDROID_LOG_FATAL, "JavaRuntime",
                        "JNI_GetCreatedJavaVMs not found: %s", dlerror());
}

__attribute__((destructor)) static void JavaRuntime_deinit(void) {
  if (JavaRuntime_dlhandle) {
    dlclose(JavaRuntime_dlhandle);
    JavaRuntime_dlhandle = nullptr;
  }

  JavaRuntime_GetDefaultJavaVMInitArgs = nullptr;
  JavaRuntime_CreateJavaVM = nullptr;
  JavaRuntime_GetCreatedJavaVMs = nullptr;
}

jint JNI_GetDefaultJavaVMInitArgs(void *vm_args) {
  if (JavaRuntime_GetDefaultJavaVMInitArgs == nullptr)
    return JNI_ERR;

  return (*JavaRuntime_GetDefaultJavaVMInitArgs)(vm_args);
}

jint JNI_CreateJavaVM(JavaVM **vm, JNIEnv **env, void *vm_args) {
  if (JavaRuntime_CreateJavaVM == nullptr)
    return JNI_ERR;

  return (*JavaRuntime_CreateJavaVM)(vm, env, vm_args);
}

jint JNI_GetCreatedJavaVMs(JavaVM **vmBuf, jsize bufLen, jsize *nVMs) {
  if (JavaRuntime_GetCreatedJavaVMs == nullptr)
    return JNI_ERR;

  return (*JavaRuntime_GetCreatedJavaVMs)(vmBuf, bufLen, nVMs);
}

#endif
