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
struct JNISetTest {

  @Test("Import: () -> Set<String> (Java)")
  func stringSet_result_java() throws {
    try assertOutput(
      input: "public func f() -> Set<String> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftSet<java.lang.String> f(SwiftArena swiftArena) {
          return SwiftSet.<java.lang.String>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """,
        """
        private static native long $f();
        """,
      ]
    )
  }

  @Test("Import: () -> Set<String> (Swift)")
  func stringSet_result_swift() throws {
    try assertOutput(
      input: "public func f() -> Set<String> {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__")
        public func Java_com_example_swift_SwiftModule__00024f__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
          return SwiftModule.f().setGetJNIValue(in: environment)
        }
        """
      ]
    )
  }

  @Test("Import: (Set<String>) -> Void (Java)")
  func stringSet_param_java() throws {
    try assertOutput(
      input: "public func f(set: Set<String>) {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static void f(org.swift.swiftkit.core.collections.SwiftSet<java.lang.String> set) {
          SwiftModule.$f(Objects.requireNonNull(set, "set must not be null").$memoryAddress());
        }
        """,
        """
        private static native void $f(long set);
        """,
      ]
    )
  }

  @Test("Import: (Set<String>) -> Void (Swift)")
  func stringSet_param_swift() throws {
    try assertOutput(
      input: "public func f(set: Set<String>) {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__J")
        public func Java_com_example_swift_SwiftModule__00024f__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, set: jlong) {
          SwiftModule.f(set: Set<String>(fromJNI: set, in: environment))
        }
        """
      ]
    )
  }

  @Test("Import: (Set<String>) -> Set<String> (Java)")
  func stringSet_roundtrip_java() throws {
    try assertOutput(
      input: "public func f(set: Set<String>) -> Set<String> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftSet<java.lang.String> f(org.swift.swiftkit.core.collections.SwiftSet<java.lang.String> set, SwiftArena swiftArena) {
          return SwiftSet.<java.lang.String>wrapMemoryAddressUnsafe(SwiftModule.$f(Objects.requireNonNull(set, "set must not be null").$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $f(long set);
        """,
      ]
    )
  }

  @Test("Import: (Set<String>) -> Set<String> (Swift)")
  func stringSet_roundtrip_swift() throws {
    try assertOutput(
      input: "public func f(set: Set<String>) -> Set<String> {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__J")
        public func Java_com_example_swift_SwiftModule__00024f__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, set: jlong) -> jlong {
          return SwiftModule.f(set: Set<String>(fromJNI: set, in: environment)).setGetJNIValue(in: environment)
        }
        """
      ]
    )
  }

  // ==== -------------------------------------------------------------------
  // MARK: Different element types

  @Test("Import: () -> Set<Int64> (Java)")
  func int64Set_result_java() throws {
    try assertOutput(
      input: "public func f() -> Set<Int64> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftSet<java.lang.Long> f(SwiftArena swiftArena) {
          return SwiftSet.<java.lang.Long>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """
      ]
    )
  }

  @Test("Import: () -> Set<Bool> (Java)")
  func boolSet_result_java() throws {
    try assertOutput(
      input: "public func f() -> Set<Bool> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftSet<java.lang.Boolean> f(SwiftArena swiftArena) {
          return SwiftSet.<java.lang.Boolean>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """
      ]
    )
  }

  @Test("Import: () -> Set<Double> (Java)")
  func doubleSet_result_java() throws {
    try assertOutput(
      input: "public func f() -> Set<Double> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftSet<java.lang.Double> f(SwiftArena swiftArena) {
          return SwiftSet.<java.lang.Double>wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena);
        }
        """
      ]
    )
  }

  // ==== -------------------------------------------------------------------
  // MARK: Multiple set parameters

  @Test("Import: (Set<String>, Set<Int64>) -> Void (Java)")
  func multipleSetParams_java() throws {
    try assertOutput(
      input: "public func f(a: Set<String>, b: Set<Int64>) {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static void f(org.swift.swiftkit.core.collections.SwiftSet<java.lang.String> a, org.swift.swiftkit.core.collections.SwiftSet<java.lang.Long> b) {
          SwiftModule.$f(Objects.requireNonNull(a, "a must not be null").$memoryAddress(), Objects.requireNonNull(b, "b must not be null").$memoryAddress());
        }
        """,
        """
        private static native void $f(long a, long b);
        """,
      ]
    )
  }

  @Test("Import: (Set<String>, Set<Int64>) -> Void (Swift)")
  func multipleSetParams_swift() throws {
    try assertOutput(
      input: "public func f(a: Set<String>, b: Set<Int64>) {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__JJ")
        public func Java_com_example_swift_SwiftModule__00024f__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, a: jlong, b: jlong) {
          SwiftModule.f(a: Set<String>(fromJNI: a, in: environment), b: Set<Int64>(fromJNI: b, in: environment))
        }
        """
      ]
    )
  }

  // ==== -------------------------------------------------------------------
  // MARK: Set with other parameter types

  @Test("Import: (Set<String>, String) -> Set<String> (Java)")
  func setWithPrimitiveParams_java() throws {
    try assertOutput(
      input: "public func f(set: Set<String>, element: String) -> Set<String> {}",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.collections.SwiftSet<java.lang.String> f(org.swift.swiftkit.core.collections.SwiftSet<java.lang.String> set, java.lang.String element, SwiftArena swiftArena) {
          return SwiftSet.<java.lang.String>wrapMemoryAddressUnsafe(SwiftModule.$f(Objects.requireNonNull(set, "set must not be null").$memoryAddress(), element), swiftArena);
        }
        """,
        """
        private static native long $f(long set, java.lang.String element);
        """,
      ]
    )
  }

  @Test("Import: (Set<String>, String) -> Set<String> (Swift)")
  func setWithPrimitiveParams_swift() throws {
    try assertOutput(
      input: "public func f(set: Set<String>, element: String) -> Set<String> {}",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024f__JLjava_lang_String_2")
        public func Java_com_example_swift_SwiftModule__00024f__JLjava_lang_String_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, set: jlong, element: jstring?) -> jlong {
          return SwiftModule.f(set: Set<String>(fromJNI: set, in: environment), element: String(fromJNI: element, in: environment)).setGetJNIValue(in: environment)
        }
        """
      ]
    )
  }
}
