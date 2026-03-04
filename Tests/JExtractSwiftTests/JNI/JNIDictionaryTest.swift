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
struct JNIDictionaryTest {

  @Test("Import: () -> [String: Int64] (Java)")
  func stringToInt64Dictionary_result_java() throws {
    try assertOutput(
      input: "public func f() -> [String: Int64] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.NativeSwiftDictionaryMap<java.lang.String, java.lang.Long> f(SwiftArena swiftArena) {
          return NativeSwiftDictionaryMap.wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """,
        """
        private static native long $f();
        """,
      ]
    )
  }

  @Test("Import: () -> [String: Int64] (Swift)")
  func stringToInt64Dictionary_result_swift() throws {
    try assertOutput(
      input: "public func f() -> [String: Int64] {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__")
        public func Java_com_example_swift_SwiftModule__00024f__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
          return SwiftModule.f().dictionaryGetJNIValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: ([String: Int64]) -> Void (Java)")
  func stringToInt64Dictionary_param_java() throws {
    try assertOutput(
      input: "public func f(dict: [String: Int64]) {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static void f(org.swift.swiftkit.core.NativeSwiftDictionaryMap<java.lang.String, java.lang.Long> dict) {
          SwiftModule.$f(Objects.requireNonNull(dict, "dict must not be null").$memoryAddress());
        }
        """,
        """
        private static native void $f(long dict);
        """,
      ]
    )
  }

  @Test("Import: ([String: Int64]) -> Void (Swift)")
  func stringToInt64Dictionary_param_swift() throws {
    try assertOutput(
      input: "public func f(dict: [String: Int64]) {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__J")
        public func Java_com_example_swift_SwiftModule__00024f__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, dict: jlong) {
          SwiftModule.f(dict: [String: Int64](fromJNI: dict, in: environment))
        }
        """
      ]
    )
  }

  @Test("Import: ([String: Int64]) -> [String: Int64] (Java)")
  func stringToInt64Dictionary_roundtrip_java() throws {
    try assertOutput(
      input: "public func f(dict: [String: Int64]) -> [String: Int64] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.NativeSwiftDictionaryMap<java.lang.String, java.lang.Long> f(org.swift.swiftkit.core.NativeSwiftDictionaryMap<java.lang.String, java.lang.Long> dict, SwiftArena swiftArena) {
          return NativeSwiftDictionaryMap.wrapMemoryAddressUnsafe(SwiftModule.$f(Objects.requireNonNull(dict, "dict must not be null").$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $f(long dict);
        """,
      ]
    )
  }

  @Test("Import: ([String: Int64]) -> [String: Int64] (Swift)")
  func stringToInt64Dictionary_roundtrip_swift() throws {
    try assertOutput(
      input: "public func f(dict: [String: Int64]) -> [String: Int64] {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__J")
        public func Java_com_example_swift_SwiftModule__00024f__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, dict: jlong) -> jlong {
          return SwiftModule.f(dict: [String: Int64](fromJNI: dict, in: environment)).dictionaryGetJNIValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: (Dictionary<String, Int64>) -> Dictionary<String, Int64> (Java)")
  func dictionary_explicitType_java() throws {
    try assertOutput(
      input: "public func f(dict: Dictionary<String, Int64>) -> Dictionary<String, Int64> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.NativeSwiftDictionaryMap<java.lang.String, java.lang.Long> f(org.swift.swiftkit.core.NativeSwiftDictionaryMap<java.lang.String, java.lang.Long> dict, SwiftArena swiftArena) {
          return NativeSwiftDictionaryMap.wrapMemoryAddressUnsafe(SwiftModule.$f(Objects.requireNonNull(dict, "dict must not be null").$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $f(long dict);
        """,
      ]
    )
  }

  @Test("Import: (Dictionary<String, Int64>) -> Dictionary<String, Int64> (Swift)")
  func dictionary_explicitType_swift() throws {
    try assertOutput(
      input: "public func f(dict: Dictionary<String, Int64>) -> Dictionary<String, Int64> {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__J")
        public func Java_com_example_swift_SwiftModule__00024f__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, dict: jlong) -> jlong {
          return SwiftModule.f(dict: [String: Int64](fromJNI: dict, in: environment)).dictionaryGetJNIValue(in: environment)
        }
        """
      ]
    )
  }
}
