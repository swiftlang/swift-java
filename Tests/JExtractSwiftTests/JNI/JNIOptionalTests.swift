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
    "JavaLong": "java.lang.Long",
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
        long result_combined$ = SwiftModule.$optionalSugar((byte) (arg.isPresent() ? 1 : 0), arg.orElse(0L));
        byte result_discriminator$ = (byte) (result_combined$ & 0xFF);
        int result_value$ = (int) (result_combined$ >> 32);
        return result_discriminator$ == 1 ? OptionalInt.of(result_value$) : OptionalInt.empty();
      }
      """,
      """
      private static native long $optionalSugar(byte arg_discriminator, long arg_value);
      """
      ]
    )
  }

  @Test
  func optionalSugar_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024optionalSugar__BJ")
        func Java_com_example_swift_SwiftModule__00024optionalSugar__BJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg_discriminator: jbyte, arg_value: jlong) -> jlong {
          let result_value$ = SwiftModule.optionalSugar(arg_discriminator == 1 ? Int64(fromJNI: arg_value, in: environment!) : nil).map {
            Int64($0) << 32 | Int64(1)
          } ?? 0
          return result_value$.getJNIValue(in: environment!)
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
        byte[] result$_discriminator$ = new byte[1];
        java.lang.String result$ = SwiftModule.$optionalExplicit((byte) (arg.isPresent() ? 1 : 0), arg.orElse(null), result$_discriminator$);
        return (result$_discriminator$[0] == 1) ? Optional.of(result$) : Optional.empty();
      }
      """,
      """
      private static native java.lang.String $optionalExplicit(byte arg_discriminator, java.lang.String arg_value, byte[] result_discriminator$);
      """
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
        @_cdecl("Java_com_example_swift_SwiftModule__00024optionalExplicit__BLjava_lang_String_2_3B")
        func Java_com_example_swift_SwiftModule__00024optionalExplicit__BLjava_lang_String_2_3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg_discriminator: jbyte, arg_value: jstring?, result_discriminator$: jbyteArray?) -> jstring? {
          let result$: jstring?
          if let innerResult$ = SwiftModule.optionalExplicit(arg_discriminator == 1 ? String(fromJNI: arg_value, in: environment!) : nil) {
            result$ = innerResult$.getJNIValue(in: environment!) 
            var flag$ = Int8(1)
            environment.interface.SetByteArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
          }
          else {
            result$ = String.jniPlaceholderValue
            var flag$ = Int8(0)
            environment.interface.SetByteArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
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
      public static Optional<MyClass> optionalClass(Optional<MyClass> arg, SwiftArena swiftArena$) {
        byte[] result$_discriminator$ = new byte[1];
        long result$ = SwiftModule.$optionalClass(arg.map(MyClass::$memoryAddress).orElse(0L), result$_discriminator$);
        return (result$_discriminator$[0] == 1) ? Optional.of(MyClass.wrapMemoryAddressUnsafe(result$, swiftArena$)) : Optional.empty();
      }
      """,
      """
      private static native long $optionalClass(long arg, byte[] result_discriminator$);
      """
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
        @_cdecl("Java_com_example_swift_SwiftModule__00024optionalClass__J_3B")
        func Java_com_example_swift_SwiftModule__00024optionalClass__J_3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg: jlong, result_discriminator$: jbyteArray?) -> jlong {
          let argBits$ = Int(Int64(fromJNI: arg, in: environment!))
          let arg$ = UnsafeMutablePointer<MyClass>(bitPattern: argBits$)
          let result$: jlong
          if let innerResult$ = SwiftModule.optionalClass(arg$?.pointee) {
            let _result$ = UnsafeMutablePointer<MyClass>.allocate(capacity: 1)
            _result$.initialize(to: innerResult$)
            let _resultBits$ = Int64(Int(bitPattern: _result$))
            result$ = _resultBits$.getJNIValue(in: environment!) 
            var flag$ = Int8(1)
            environment.interface.SetByteArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
          }
          else {
            result$ = 0
            var flag$ = Int8(0)
            environment.interface.SetByteArrayRegion(environment, result_discriminator$, 0, 1, &flag$)
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
      public static void optionalJavaKitClass(Optional<java.lang.Long> arg) {
        SwiftModule.$optionalJavaKitClass(arg.orElse(null));
      }
      """,
      """
      private static native void $optionalJavaKitClass(java.lang.Long arg);
      """
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
        func Java_com_example_swift_SwiftModule__00024optionalJavaKitClass__Ljava_lang_Long_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg: jobject?) {
          SwiftModule.optionalJavaKitClass(arg.map {
            return JavaLong(javaThis: $0, environment: environment!)
          }
          )
        }
        """
      ]
    )
  }
}
