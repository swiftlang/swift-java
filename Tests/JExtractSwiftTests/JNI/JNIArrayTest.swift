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
struct JNIArrayTest {

  @Test("Import: (Array<UInt8>) -> Array<UInt8> (Java)")
  func uint8Array_explicitType_java() throws {
    try assertOutput(
      input: "public func f(array: Array<UInt8>) -> Array<UInt8> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static byte[] f(@Unsigned byte[] array) {
          return SwiftModule.$f(Objects.requireNonNull(array, "array must not be null"));
        }
        """,
        """
        private static native byte[] $f(byte[] array);
        """,
      ]
    )
  }

  @Test("Import: (Array<UInt8>) -> Array<UInt8> (Swift)")
  func uint8Array_explicitType_swift() throws {
    try assertOutput(
      input: "public func f(array: Array<UInt8>) -> Array<UInt8> {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3B")
        public func Java_com_example_swift_SwiftModule__00024f___3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jbyteArray?) -> jbyteArray? {
          return SwiftModule.f(array: [UInt8](fromJNI: array, in: environment)).getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: ([UInt8]) -> [UInt8] (Java)")
  func uint8Array_syntaxSugar_java() throws {
    try assertOutput(
      input: "public func f(array: Array<UInt8>) -> Array<UInt8> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static byte[] f(@Unsigned byte[] array) {
          return SwiftModule.$f(Objects.requireNonNull(array, "array must not be null"));
        }
        """,
        """
        private static native byte[] $f(byte[] array);
        """,
      ]
    )
  }

  @Test("Import: ([UInt8]) -> [UInt8] (Swift)")
  func uint8Array_syntaxSugar_swift() throws {
    try assertOutput(
      input: "public func f(array: [UInt8]) -> [UInt8] {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3B")
        public func Java_com_example_swift_SwiftModule__00024f___3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jbyteArray?) -> jbyteArray? {
          return SwiftModule.f(array: [UInt8](fromJNI: array, in: environment)).getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: ([Int64]) -> [Int64] (Java)")
  func int64Array_syntaxSugar_java() throws {
    try assertOutput(
      input: "public func f(array: [Int64]) -> [Int64] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static long[] f(long[] array) {
          return SwiftModule.$f(Objects.requireNonNull(array, "array must not be null"));
        }
        """,
        """
        private static native long[] $f(long[] array);
        """,
      ]
    )
  }

  @Test("Import: ([Int64]) -> [Int64] (Swift)")
  func int64Array_syntaxSugar_swift() throws {
    try assertOutput(
      input: "public func f(array: [Int64]) -> [Int64] {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3J")
        public func Java_com_example_swift_SwiftModule__00024f___3J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jlongArray?) -> jlongArray? {
          return SwiftModule.f(array: [Int64](fromJNI: array, in: environment)).getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: ([MySwiftClass]) -> [MySwiftClass] (Java)")
  func swiftClassArray_syntaxSugar_java() throws {
    try assertOutput(
      input: """
          public class MySwiftClass {}
          public func f(array: [MySwiftClass]) -> [MySwiftClass] {}
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static MySwiftClass[] f(MySwiftClass[] array, SwiftArena swiftArena) {
          return Arrays.stream(SwiftModule.$f(Arrays.stream(Objects.requireNonNull(array, "array must not be null")).mapToLong(MySwiftClass::$memoryAddress).toArray())).mapToObj((pointer) -> {
            return MySwiftClass.wrapMemoryAddressUnsafe(pointer, swiftArena);
          }
          ).toArray(MySwiftClass[]::new);
        }
        """,
        """
        private static native long[] $f(long[] array);
        """,
      ]
    )
  }

  @Test("Import: ([MySwiftClass]) -> [MySwiftClass] (Swift)")
  func swiftClassArray_syntaxSugar_swift() throws {
    try assertOutput(
      input: """
          public class MySwiftClass {}
          public func f(array: [MySwiftClass]) -> [MySwiftClass] {}
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3J")
        public func Java_com_example_swift_SwiftModule__00024f___3J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jlongArray?) -> jlongArray? {
          return SwiftModule.f(array: [Int64](fromJNI: array, in: environment).map( { (pointer$) in
            assert(pointer$ != 0, "pointer$ memory address was null")
            let pointer$Bits$ = Int(pointer$)
            let pointer$$ = UnsafeMutablePointer<MySwiftClass>(bitPattern: pointer$Bits$)
            guard let pointer$$ else {
              fatalError("pointer$ memory address was null in call to \\(#function)!")
            }
            return pointer$$.pointee
          }
          )).map( { (object$) in
            let object$$ = UnsafeMutablePointer<MySwiftClass>.allocate(capacity: 1)
            object$$.initialize(to: object$)
            let object$Bits$ = Int64(Int(bitPattern: object$$))
            return object$Bits$
          }
          ).getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Nested arrays (array of arrays)

  @Test("Import: ([[UInt8]]) -> byte[][] (Java)")
  func uint8NestedArray_java() throws {
    try assertOutput(
      input: "public func f(data: [[UInt8]]) -> [[UInt8]] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @Unsigned
        public static byte[][] f(@Unsigned byte[][] data) {
          return SwiftModule.$f(Objects.requireNonNull(data, "data must not be null"));
        }
        """,
        """
        private static native byte[][] $f(byte[][] data);
        """,
      ]
    )
  }

  @Test("Import: ([[UInt8]]) -> byte[][] (Swift)")
  func uint8NestedArray_swift() throws {
    try assertOutput(
      input: "public func f(data: [[UInt8]]) -> [[UInt8]] {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3_3B")
        public func Java_com_example_swift_SwiftModule__00024f___3_3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, data: jobjectArray?) -> jobjectArray? {
          return SwiftModule.f(data: [[UInt8]](fromJNI: data, in: environment)).getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: ([[Int64]]) -> long[][] (Java)")
  func int64NestedArray_java() throws {
    try assertOutput(
      input: "public func f(data: [[Int64]]) -> [[Int64]] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static long[][] f(long[][] data) {
          return SwiftModule.$f(Objects.requireNonNull(data, "data must not be null"));
        }
        """,
        """
        private static native long[][] $f(long[][] data);
        """,
      ]
    )
  }

  @Test("Import: ([[Int64]]) -> long[][] (Swift)")
  func int64NestedArray_swift() throws {
    try assertOutput(
      input: "public func f(data: [[Int64]]) -> [[Int64]] {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3_3J")
        public func Java_com_example_swift_SwiftModule__00024f___3_3J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, data: jobjectArray?) -> jobjectArray? {
          return SwiftModule.f(data: [[Int64]](fromJNI: data, in: environment)).getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: ([[String]]) -> String[][] (Java)")
  func stringNestedArray_java() throws {
    try assertOutput(
      input: "public func f(data: [[String]]) -> [[String]] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static java.lang.String[][] f(java.lang.String[][] data) {
          return SwiftModule.$f(Objects.requireNonNull(data, "data must not be null"));
        }
        """,
        """
        private static native java.lang.String[][] $f(java.lang.String[][] data);
        """,
      ]
    )
  }

  @Test("Import: ([[String]]) -> String[][] (Swift)")
  func stringNestedArray_swift() throws {
    try assertOutput(
      input: "public func f(data: [[String]]) -> [[String]] {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3_3Ljava_lang_String_2")
        public func Java_com_example_swift_SwiftModule__00024f___3_3Ljava_lang_String_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, data: jobjectArray?) -> jobjectArray? {
          return SwiftModule.f(data: [[String]](fromJNI: data, in: environment)).getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Tuples with array elements

  @Test("Import: () -> (name: [UInt8], another: [UInt8]) (Java)")
  func tupleByteArrays_java() throws {
    try assertOutput(
      input: "public func namedByteArrayTuple() -> (name: [UInt8], another: [UInt8]) {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @Unsigned
        public static LabeledTuple_namedByteArrayTuple_name_another<byte[], byte[]> namedByteArrayTuple() {
          byte[][] result_0$ = new byte[1][];
          byte[][] result_1$ = new byte[1][];
          SwiftModule.$namedByteArrayTuple(result_0$, result_1$);
          return new LabeledTuple_namedByteArrayTuple_name_another<byte[], byte[]>(result_0$[0], result_1$[0]);
        }
        """,
        """
        private static native void $namedByteArrayTuple(byte[][] result_0$, byte[][] result_1$);
        """,
      ]
    )
  }

  @Test("Import: () -> (name: [UInt8], another: [UInt8]) (Swift)")
  func tupleByteArrays_swift() throws {
    try assertOutput(
      input: "public func namedByteArrayTuple() -> (name: [UInt8], another: [UInt8]) {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024namedByteArrayTuple___3_3B_3_3B")
        public func Java_com_example_swift_SwiftModule__00024namedByteArrayTuple___3_3B_3_3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, result_0$: jobjectArray?, result_1$: jobjectArray?) {
          let tupleResult$ = SwiftModule.namedByteArrayTuple()
          let element_0_jni$ = tupleResult$.name.getJNILocalRefValue(in: environment)
          environment.interface.SetObjectArrayElement(environment, result_0$, 0, element_0_jni$)
          let element_1_jni$ = tupleResult$.another.getJNILocalRefValue(in: environment)
          environment.interface.SetObjectArrayElement(environment, result_1$, 0, element_1_jni$)
          return
        }
        """
      ]
    )
  }
}
