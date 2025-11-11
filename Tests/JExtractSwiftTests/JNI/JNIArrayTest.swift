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
      .jni, .java,
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
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3B")
        func Java_com_example_swift_SwiftModule__00024f___3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jbyteArray?) -> jbyteArray? { 
          return SwiftModule.f(array: [UInt8](fromJNI: array, in: environment)).getJNIValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: ([UInt8]) -> [UInt8] (Java)")
  func uint8Array_syntaxSugar_java() throws {
    try assertOutput(
      input: "public func f(array: Array<UInt8>) -> Array<UInt8> {}",
      .jni, .java,
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
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3B")
        func Java_com_example_swift_SwiftModule__00024f___3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jbyteArray?) -> jbyteArray? { 
          return SwiftModule.f(array: [UInt8](fromJNI: array, in: environment)).getJNIValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: ([Int64]) -> [Int64] (Java)")
  func int64Array_syntaxSugar_java() throws {
    try assertOutput(
      input: "public func f(array: [Int64]) -> [Int64] {}",
      .jni, .java,
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
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3J")
        func Java_com_example_swift_SwiftModule__00024f___3J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jlongArray?) -> jlongArray? { 
          return SwiftModule.f(array: [Int64](fromJNI: array, in: environment)).getJNIValue(in: environment)
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
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static MySwiftClass[] f(MySwiftClass[] array, SwiftArena swiftArena$) { 
          return Arrays.stream(SwiftModule.$f(Arrays.stream(Objects.requireNonNull(array, "array must not be null")).mapToLong(MySwiftClass::$memoryAddress).toArray())).mapToObj((pointer) -> { 
            return MySwiftClass.wrapMemoryAddressUnsafe(pointer, swiftArena$);
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
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f___3J")
        func Java_com_example_swift_SwiftModule__00024f___3J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jlongArray?) -> jlongArray? { 
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
          ).getJNIValue(in: environment)
        }
        """
      ]
    )
  }
}
