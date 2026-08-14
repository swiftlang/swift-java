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
    public func closureLongSupplier(closure: () -> Int64) {}
    public func closureDoubleSupplier(closure: () -> Double) {}

    public func closureIntConsumer(closure: (Int32) -> Void) {}
    public func closureLongConsumer(closure: (Int64) -> Void) {}
    public func closureDoubleConsumer(closure: (Double) -> Void) {}

    public func closureIntPredicate(closure: (Int32) -> Bool) {}
    public func closureLongPredicate(closure: (Int64) -> Bool) {}
    public func closureDoublePredicate(closure: (Double) -> Bool) {}

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
  func closureLongSupplier_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureLongSupplier(closure: () -> Int64)
         * }
         */
        public static void closureLongSupplier(java.util.function.LongSupplier closure) {
          SwiftModule.$closureLongSupplier(closure);
        }
        """,
        """
        private static native void $closureLongSupplier(java.util.function.LongSupplier closure);
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
  func closureIntConsumer_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureIntConsumer(closure: (Int32) -> Void)
         * }
         */
        public static void closureIntConsumer(java.util.function.IntConsumer closure) {
          SwiftModule.$closureIntConsumer(closure);
        }
        """,
        """
        private static native void $closureIntConsumer(java.util.function.IntConsumer closure);
        """,
      ]
    )
  }

  @Test
  func closureLongConsumer_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureLongConsumer(closure: (Int64) -> Void)
         * }
         */
        public static void closureLongConsumer(java.util.function.LongConsumer closure) {
          SwiftModule.$closureLongConsumer(closure);
        }
        """,
        """
        private static native void $closureLongConsumer(java.util.function.LongConsumer closure);
        """,
      ]
    )
  }

  @Test
  func closureDoubleConsumer_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureDoubleConsumer(closure: (Double) -> Void)
         * }
         */
        public static void closureDoubleConsumer(java.util.function.DoubleConsumer closure) {
          SwiftModule.$closureDoubleConsumer(closure);
        }
        """,
        """
        private static native void $closureDoubleConsumer(java.util.function.DoubleConsumer closure);
        """,
      ]
    )
  }

  @Test
  func closureIntPredicate_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureIntPredicate(closure: (Int32) -> Bool)
         * }
         */
        public static void closureIntPredicate(java.util.function.IntPredicate closure) {
          SwiftModule.$closureIntPredicate(closure);
        }
        """,
        """
        private static native void $closureIntPredicate(java.util.function.IntPredicate closure);
        """,
      ]
    )
  }

  @Test
  func closureLongPredicate_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureLongPredicate(closure: (Int64) -> Bool)
         * }
         */
        public static void closureLongPredicate(java.util.function.LongPredicate closure) {
          SwiftModule.$closureLongPredicate(closure);
        }
        """,
        """
        private static native void $closureLongPredicate(java.util.function.LongPredicate closure);
        """,
      ]
    )
  }

  @Test
  func closureDoublePredicate_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func closureDoublePredicate(closure: (Double) -> Bool)
         * }
         */
        public static void closureDoublePredicate(java.util.function.DoublePredicate closure) {
          SwiftModule.$closureDoublePredicate(closure);
        }
        """,
        """
        private static native void $closureDoublePredicate(java.util.function.DoublePredicate closure);
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
  func closureLongSupplier_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureLongSupplier__Ljava_util_function_LongSupplier_2")
        public func Java_com_example_swift_SwiftModule__00024closureLongSupplier__Ljava_util_function_LongSupplier_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureLongSupplier(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "getAsLong", "()J")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = []
            return Int64(fromJNI: environment.interface.CallLongMethodA(environment, closure, methodID$, arguments$), in: environment)
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
  func closureIntConsumer_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureIntConsumer__Ljava_util_function_IntConsumer_2")
        public func Java_com_example_swift_SwiftModule__00024closureIntConsumer__Ljava_util_function_IntConsumer_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureIntConsumer(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "accept", "(I)V")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = [_0.getJValue(in: environment)]
            environment.interface.CallVoidMethodA(environment, closure, methodID$, arguments$)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureLongConsumer_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureLongConsumer__Ljava_util_function_LongConsumer_2")
        public func Java_com_example_swift_SwiftModule__00024closureLongConsumer__Ljava_util_function_LongConsumer_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureLongConsumer(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "accept", "(J)V")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = [_0.getJValue(in: environment)]
            environment.interface.CallVoidMethodA(environment, closure, methodID$, arguments$)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureDoubleConsumer_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureDoubleConsumer__Ljava_util_function_DoubleConsumer_2")
        public func Java_com_example_swift_SwiftModule__00024closureDoubleConsumer__Ljava_util_function_DoubleConsumer_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureDoubleConsumer(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "accept", "(D)V")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = [_0.getJValue(in: environment)]
            environment.interface.CallVoidMethodA(environment, closure, methodID$, arguments$)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureIntPredicate_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureIntPredicate__Ljava_util_function_IntPredicate_2")
        public func Java_com_example_swift_SwiftModule__00024closureIntPredicate__Ljava_util_function_IntPredicate_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureIntPredicate(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "test", "(I)Z")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = [_0.getJValue(in: environment)]
            return Bool(fromJNI: environment.interface.CallBooleanMethodA(environment, closure, methodID$, arguments$), in: environment)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureLongPredicate_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureLongPredicate__Ljava_util_function_LongPredicate_2")
        public func Java_com_example_swift_SwiftModule__00024closureLongPredicate__Ljava_util_function_LongPredicate_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureLongPredicate(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "test", "(J)Z")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = [_0.getJValue(in: environment)]
            return Bool(fromJNI: environment.interface.CallBooleanMethodA(environment, closure, methodID$, arguments$), in: environment)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func closureDoublePredicate_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024closureDoublePredicate__Ljava_util_function_DoublePredicate_2")
        public func Java_com_example_swift_SwiftModule__00024closureDoublePredicate__Ljava_util_function_DoublePredicate_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.closureDoublePredicate(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "test", "(D)Z")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = [_0.getJValue(in: environment)]
            return Bool(fromJNI: environment.interface.CallBooleanMethodA(environment, closure, methodID$, arguments$), in: environment)
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
