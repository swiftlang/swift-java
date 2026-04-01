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
        public static org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> f(SwiftArena swiftArena) {
          return SwiftDictionaryMap.<java.lang.String, java.lang.Long>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
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
        public static void f(org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> dict) {
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
        public static org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> f(org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> dict, SwiftArena swiftArena) {
          return SwiftDictionaryMap.<java.lang.String, java.lang.Long>wrapMemoryAddressUnsafe(SwiftModule.$f(Objects.requireNonNull(dict, "dict must not be null").$memoryAddress()), swiftArena);
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
        public static org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> f(org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> dict, SwiftArena swiftArena) {
          return SwiftDictionaryMap.<java.lang.String, java.lang.Long>wrapMemoryAddressUnsafe(SwiftModule.$f(Objects.requireNonNull(dict, "dict must not be null").$memoryAddress()), swiftArena);
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

  // ==== ---------------------------------------------------------------------
  // MARK: Different value types

  @Test("Import: () -> [String: Bool] (Java)")
  func stringToBoolDictionary_result_java() throws {
    try assertOutput(
      input: "public func f() -> [String: Bool] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Boolean> f(SwiftArena swiftArena) {
          return SwiftDictionaryMap.<java.lang.String, java.lang.Boolean>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """
      ]
    )
  }

  @Test("Import: () -> [String: Double] (Java)")
  func stringToDoubleDictionary_result_java() throws {
    try assertOutput(
      input: "public func f() -> [String: Double] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Double> f(SwiftArena swiftArena) {
          return SwiftDictionaryMap.<java.lang.String, java.lang.Double>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """
      ]
    )
  }

  @Test("Import: () -> [Int64: String] (Java) — non-String key")
  func int64ToStringDictionary_result_java() throws {
    try assertOutput(
      input: "public func f() -> [Int64: String] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.Long, java.lang.String> f(SwiftArena swiftArena) {
          return SwiftDictionaryMap.<java.lang.Long, java.lang.String>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """
      ]
    )
  }

  @Test("Import: () -> [Int32: Float] (Java)")
  func int32ToFloatDictionary_result_java() throws {
    try assertOutput(
      input: "public func f() -> [Int32: Float] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.Integer, java.lang.Float> f(SwiftArena swiftArena) {
          return SwiftDictionaryMap.<java.lang.Integer, java.lang.Float>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """
      ]
    )
  }

  // ==== ---------------------------------------------------------------------
  // MARK: Multiple dictionary parameters

  @Test("Import: ([String: Int64], [String: Bool]) -> Void (Java)")
  func multipleDictionaryParams_java() throws {
    try assertOutput(
      input: "public func f(a: [String: Int64], b: [String: Bool]) {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static void f(org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> a, org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Boolean> b) {
          SwiftModule.$f(Objects.requireNonNull(a, "a must not be null").$memoryAddress(), Objects.requireNonNull(b, "b must not be null").$memoryAddress());
        }
        """,
        """
        private static native void $f(long a, long b);
        """,
      ]
    )
  }

  @Test("Import: ([String: Int64], [String: Bool]) -> Void (Swift)")
  func multipleDictionaryParams_swift() throws {
    try assertOutput(
      input: "public func f(a: [String: Int64], b: [String: Bool]) {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__JJ")
        public func Java_com_example_swift_SwiftModule__00024f__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, a: jlong, b: jlong) {
          SwiftModule.f(a: [String: Int64](fromJNI: a, in: environment), b: [String: Bool](fromJNI: b, in: environment))
        }
        """
      ]
    )
  }

  // ==== ---------------------------------------------------------------------
  // MARK: Dictionary with other parameter types

  @Test("Import: ([String: Int64], String, Int64) -> [String: Int64] (Java)")
  func dictionaryWithPrimitiveParams_java() throws {
    try assertOutput(
      input: "public func f(dict: [String: Int64], key: String, value: Int64) -> [String: Int64] {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> f(org.swift.swiftkit.core.collections.SwiftDictionaryMap<java.lang.String, java.lang.Long> dict, java.lang.String key, long value, SwiftArena swiftArena) {
          return SwiftDictionaryMap.<java.lang.String, java.lang.Long>wrapMemoryAddressUnsafe(SwiftModule.$f(Objects.requireNonNull(dict, "dict must not be null").$memoryAddress(), key, value), swiftArena);
        }
        """,
        """
        private static native long $f(long dict, java.lang.String key, long value);
        """,
      ]
    )
  }

  @Test("Import: ([String: Int64], String, Int64) -> [String: Int64] (Swift)")
  func dictionaryWithPrimitiveParams_swift() throws {
    try assertOutput(
      input: "public func f(dict: [String: Int64], key: String, value: Int64) -> [String: Int64] {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__JLjava_lang_String_2J")
        public func Java_com_example_swift_SwiftModule__00024f__JLjava_lang_String_2J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, dict: jlong, key: jstring?, value: jlong) -> jlong {
          return SwiftModule.f(dict: [String: Int64](fromJNI: dict, in: environment), key: String(fromJNI: key, in: environment), value: Int64(fromJNI: value, in: environment)).dictionaryGetJNIValue(in: environment)
        }
        """
      ]
    )
  }
}
