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

import JExtractSwiftLib
import Testing

@Suite
struct JNIClosureTests {
  let source =
    """
    public func emptyClosure(closure: () -> ()) {}
    public func closureBoolSupplier(closure: () -> Bool) {}
    public func closureIntSupplier(closure: () -> Int32) {}
    public func closureDoubleSupplier(closure: () -> Double) {}
    public func closureWithArgumentsAndReturn(closure: (Int64, Bool) -> Int64) {}
    """

  @Test
  func emptyClosure_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func emptyClosure(closure: () -> ())
         * }
         */
        public static void emptyClosure(java.lang.Runnable closure) {
          SwiftModule.$emptyClosure(closure);
        }
        """,
        """
        private static native void $emptyClosure(java.lang.Runnable closure);
        """,
      ]
    )
  }

  @Test
  func closureBoolSupplier_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureBoolSupplier(closure: () -> Bool)
         * }
         */
        public static void closureBoolSupplier(java.util.function.BooleanSupplier closure) {
          SwiftModule.$closureBoolSupplier(closure);
        }
        """,
        """
        private static native void $closureBoolSupplier(java.util.function.BooleanSupplier closure);
        """,
      ]
    )
  }

  @Test
  func closureIntSupplier_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureIntSupplier(closure: () -> Int32)
         * }
         */
        public static void closureIntSupplier(java.util.function.IntSupplier closure) {
          SwiftModule.$closureIntSupplier(closure);
        }
        """,
        """
        private static native void $closureIntSupplier(java.util.function.IntSupplier closure);
        """,
      ]
    )
  }

  @Test
  func closureDoubleSupplier_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureDoubleSupplier(closure: () -> Double)
         * }
         */
        public static void closureDoubleSupplier(java.util.function.DoubleSupplier closure) {
          SwiftModule.$closureDoubleSupplier(closure);
        }
        """,
        """
        private static native void $closureDoubleSupplier(java.util.function.DoubleSupplier closure);
        """,
      ]
    )
  }

  @Test
  func emptyClosure_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024emptyClosure__Ljava_lang_Runnable_2")
        public func Java_com_example_swift_SwiftModule__00024emptyClosure__Ljava_lang_Runnable_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.emptyClosure(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "run", "()V")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = []
            environment.interface.CallVoidMethodA(environment, closure, methodID$, arguments$)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureBoolSupplier_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureBoolSupplier__Ljava_util_function_BooleanSupplier_2")
        public func Java_com_example_swift_SwiftModule__00024closureBoolSupplier__Ljava_util_function_BooleanSupplier_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureBoolSupplier(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "getAsBoolean", "()Z")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = []
            return Bool(fromJNI: environment.interface.CallBooleanMethodA(environment, closure, methodID$, arguments$), in: environment)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureIntSupplier_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureIntSupplier__Ljava_util_function_IntSupplier_2")
        public func Java_com_example_swift_SwiftModule__00024closureIntSupplier__Ljava_util_function_IntSupplier_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureIntSupplier(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "getAsInt", "()I")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = []
            return Int32(fromJNI: environment.interface.CallIntMethodA(environment, closure, methodID$, arguments$), in: environment)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureDoubleSupplier_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureDoubleSupplier__Ljava_util_function_DoubleSupplier_2")
        public func Java_com_example_swift_SwiftModule__00024closureDoubleSupplier__Ljava_util_function_DoubleSupplier_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureDoubleSupplier(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "getAsDouble", "()D")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = []
            return Double(fromJNI: environment.interface.CallDoubleMethodA(environment, closure, methodID$, arguments$), in: environment)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureWithArgumentsAndReturn_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        public static class closureWithArgumentsAndReturn {
          /** Corresponds to the Swift closure parameter of type {@code (Int64, Bool) -> Int64}. */
          @FunctionalInterface
          public interface closure {
            long apply(long _0, boolean _1);
          }
        }
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureWithArgumentsAndReturn(closure: (Int64, Bool) -> Int64)
         * }
         */
        public static void closureWithArgumentsAndReturn(com.example.swift.SwiftModule.closureWithArgumentsAndReturn.closure closure) {
          SwiftModule.$closureWithArgumentsAndReturn(closure);
        }
        """,
        """
        private static native void $closureWithArgumentsAndReturn(com.example.swift.SwiftModule.closureWithArgumentsAndReturn.closure closure);
        """,
      ]
    )
  }

  @Test
  func closureWithArgumentsAndReturn_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureWithArgumentsAndReturn__Lcom_example_swift_SwiftModule_00024closureWithArgumentsAndReturn_00024closure_2")
        public func Java_com_example_swift_SwiftModule__00024closureWithArgumentsAndReturn__Lcom_example_swift_SwiftModule_00024closureWithArgumentsAndReturn_00024closure_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureWithArgumentsAndReturn(closure: { _0, _1 in
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "apply", "(JZ)J")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = [_0.getJValue(in: environment), _1.getJValue(in: environment)]
            return Int64(fromJNI: environment.interface.CallLongMethodA(environment, closure, methodID$, arguments$), in: environment)
          }
          )
        }
        """
      ]
    )
  }
}
