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
struct JNIOptionalTests {
  let source =
    """
    class MyClass { }

    public func optionalSugar(_ arg: Int64?) -> Int32?
    public func optionalExplicit(_ arg: Optional<String>) -> Optional<String>
    public func optionalClass(_ arg: MyClass?) -> MyClass?
    public func optionalJavaKitClass(_ arg: JavaLong?)
    """

  let classLookupTable = [
    "JavaLong": "java.lang.Long"
  ]

  @Test
  func optionalSugar_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func optionalSugar(_ arg: Int64?) -> Int32?
         * }
         */
        public static OptionalInt optionalSugar(OptionalLong arg) {
          long result_combined$ = SwiftModule.$optionalSugar(arg.isPresent(), arg.orElse(0L));
          byte result_discriminator$ = (byte) (result_combined$ & 0xFF);
          int result_value$ = (int) (result_combined$ >> 32);
          return result_discriminator$ == 1 ? OptionalInt.of(result_value$) : OptionalInt.empty();
        }
        """,
        """
        private static native long $optionalSugar(boolean arg_discriminator, long arg_value);
        """,
      ]
    )
  }

  @Test
  func optionalSugar_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 2,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024optionalSugar__ZJ")
        public func Java_com_example_swift_SwiftModule__00024optionalSugar__ZJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg_discriminator: jboolean, arg_value: jlong) -> jlong {
          let result_value$ = SwiftModule.optionalSugar(arg_discriminator == jboolean(JNI_TRUE) ? Int64(fromJNI: arg_value, in: environment) : nil).map {
            Int64($0) << 32 | Int64(1)
          } ?? 0
          return result_value$.getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  @Test
  func optionalExplicit_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func optionalExplicit(_ arg: Optional<String>) -> Optional<String>
         * }
         */
        public static Optional<String> optionalExplicit(Optional<String> arg) {
          boolean[] result$_discriminator$ = new boolean[1];
          java.lang.String result$ = SwiftModule.$optionalExplicit(arg.isPresent(), arg.orElse(null), result$_discriminator$);
          return (result$_discriminator$[0]) ? Optional.of(result$) : Optional.empty();
        }
        """,
        """
        private static native java.lang.String $optionalExplicit(boolean arg_discriminator, java.lang.String arg_value, boolean[] result_discriminator$);
        """,
      ]
    )
  }

  @Test
  func optionalExplicit_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024optionalExplicit__ZLjava_lang_String_2_3Z")
        public func Java_com_example_swift_SwiftModule__00024optionalExplicit__ZLjava_lang_String_2_3Z(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg_discriminator: jboolean, arg_value: jstring?, result_discriminator$: jbooleanArray?) -> jstring? {
          let result$: jstring?
          if let innerResult$ = SwiftModule.optionalExplicit(arg_discriminator == jboolean(JNI_TRUE) ? String(fromJNI: arg_value, in: environment) : nil) {
            result$ = innerResult$.getJNIValue(in: environment)
            var flag$ = jboolean(JNI_TRUE)
            environment.interface.SetBooleanArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
          }
          else {
            result$ = nil
            var flag$ = jboolean(JNI_FALSE)
            environment.interface.SetBooleanArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
          }
          return result$
        }
        """
      ]
    )
  }

  @Test
  func optionalClass_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func optionalClass(_ arg: MyClass?) -> MyClass?
         * }
         */
        public static java.util.Optional<MyClass> optionalClass(java.util.Optional<MyClass> arg, SwiftArena swiftArena) {
          boolean[] result$_discriminator$ = new boolean[1];
          long result$ = SwiftModule.$optionalClass(arg.map(MyClass::$memoryAddress).orElse(0L), result$_discriminator$);
          return (result$_discriminator$[0]) ? Optional.of(MyClass.wrapMemoryAddressUnsafe(result$, swiftArena)) : Optional.empty();
        }
        """,
        """
        private static native long $optionalClass(long arg, boolean[] result_discriminator$);
        """,
      ]
    )
  }

  @Test
  func optionalClass_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024optionalClass__J_3Z")
        public func Java_com_example_swift_SwiftModule__00024optionalClass__J_3Z(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg: jlong, result_discriminator$: jbooleanArray?) -> jlong {
          let argBits$ = Int(Int64(fromJNI: arg, in: environment))
          let arg$ = UnsafeMutablePointer<MyClass>(bitPattern: argBits$)
          let result$: jlong
          if let innerResult$ = SwiftModule.optionalClass(arg$?.pointee) {
            let resultWrapped$ = UnsafeMutablePointer<MyClass>.allocate(capacity: 1)
            resultWrapped$.initialize(to: innerResult$)
            let resultWrappedBits$ = Int64(Int(bitPattern: resultWrapped$))
            result$ = resultWrappedBits$.getJNILocalRefValue(in: environment)
            var flag$ = jboolean(JNI_TRUE)
            environment.interface.SetBooleanArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
          }
          else {
            result$ = 0
            var flag$ = jboolean(JNI_FALSE)
            environment.interface.SetBooleanArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
          }
          return result$
        }
        """
      ]
    )
  }

  @Test
  func optionalJavaKitClass_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func optionalJavaKitClass(_ arg: JavaLong?)
         * }
         */
        public static void optionalJavaKitClass(java.util.Optional<java.lang.Long> arg) {
          SwiftModule.$optionalJavaKitClass(arg.orElse(null));
        }
        """,
        """
        private static native void $optionalJavaKitClass(java.lang.Long arg);
        """,
      ]
    )
  }

  @Test
  func optionalJavaKitClass_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024optionalJavaKitClass__Ljava_lang_Long_2")
        public func Java_com_example_swift_SwiftModule__00024optionalJavaKitClass__Ljava_lang_Long_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg: jobject?) {
          SwiftModule.optionalJavaKitClass(arg.map {
            return JavaLong(javaThis: $0, environment: environment)
          }
          )
        }
        """
      ]
    )
  }

  @Test
  func optionalTuple() throws {
    let input = """
      public struct Foo {}
      public func optionalTuple() -> (Int64?, Foo)? {
        (42, Foo())
      }
      """

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        boolean[] result$_discriminator$ = new boolean[1];
        boolean[] resultWrapped$_0$$_discriminator$ = new boolean[1];
        long[] resultWrapped$_0$ = new long[1];
        long[] resultWrapped$_1$ = new long[1];
        SwiftModule.$optionalTuple(result$_discriminator$, resultWrapped$_0$$_discriminator$, resultWrapped$_0$, resultWrapped$_1$);
        """,
        """
        private static native void $optionalTuple(boolean[] result_discriminator$, boolean[] resultWrapped_0$_discriminator$, long[] resultWrapped_0$, long[] resultWrapped_1$);
        """,
      ]
    )
  }
}
