//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Testing

@Suite
struct JavaKeywordTests {
  @Test
  func functionName() throws {
    let text =
      """
      public struct Foo {
        public func final()
      }
      """

    try assertOutput(
      input: text,
      .ffm,
      .java,
      expectedChunks: [
        """
        private static final MemorySegment ADDR =
          SwiftModule.findOrThrow("swiftjava_SwiftModule_Foo_final");
        """,
        """
        public void final_() {
        """,
      ]
    )

    try assertOutput(
      input: text,
      .ffm,
      .swift,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_Foo_final")
        """
      ]
    )
  }

  @Test
  func enumCase() throws {
    let text =
      """
      public enum MyEnum {
        case null
      }
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      expectedChunks: [
        """
        public static MyEnum null_(SwiftArena swiftArena) {
        """,
        """
        record Null() implements Case {
        """,
      ]
    )
  }

  @Test
  func enumCaseWithAssociatedValue() throws {
    let text =
      """
      public enum MyEnumWithValue {
        case instanceof(String)
        case none
      }
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      expectedChunks: [
        """
        public static MyEnumWithValue instanceof_(java.lang.String arg0, SwiftArena swiftArena) {
        """,
        """
        record Instanceof(java.lang.String arg0) implements Case {
        """,
        """
        public java.util.Optional<Case.Instanceof> getAsInstanceof() {
        """,
      ]
    )

    try assertOutput(
      input: text,
      .jni,
      .swift,
      expectedChunks: [
        """
        extension MyEnumWithValue {
          fileprivate func getAsInstanceof() -> (String)? {
        """
      ]
    )
  }

  @Test
  func enumCaseWithBacktick() throws {
    let text =
      """
      public enum MyEnum {
        case `default`
      }
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      expectedChunks: [
        """
        public static MyEnum default_(SwiftArena swiftArena) {
        """,
        """
        record Default() implements Case {
        """,
      ]
    )
  }

  @Test
  func jniParameterNames() throws {
    let text =
      """
      public struct Side {
        public func scale(double: Double, int: Int64, `default`: Bool) -> Double
      }
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public double scale(double double_, long int_, boolean default_) {",
        "return Side.$scale(double_, int_, default_, this.$memoryAddress());",
      ]
    )

    try assertOutput(
      input: text,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "thisClass: jclass, double_: jdouble, int_: jlong, default_: jboolean, selfPointer: jlong) -> jdouble {",
        "scale(double: Double(fromJNI: double_, in: environment), int: Int64(fromJNI: int_, in: environment), default: Bool(fromJNI: default_, in: environment))",
      ]
    )
  }

  @Test
  func jniEnumCasePayloadNames() throws {
    let text =
      """
      public enum Pricing {
        case quote(slug: String, long: Int64)
      }
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "record Quote(java.lang.String slug, long long_) implements Case {}"
      ]
    )

    try assertOutput(
      input: text,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "if case let .quote(slug, long_) = self {"
      ]
    )
  }

  @Test
  func backtickedPropertyName() throws {
    try assertOutput(
      input: """
        public struct Side {
          public static var `default`: Side
        }
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public static Side getDefault(SwiftArena swiftArena) {"
      ],
      notExpectedChunks: ["get`default`"]
    )
  }

  @Test
  func finalObjectMethodNames() throws {
    try assertOutput(
      input: """
        public struct Lock {
          public var `class`: String
          public func wait()
          public func notify(_ count: Int64)
        }
        """,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public java.lang.String getClass_() {",
        "public void wait_() {",
        "public void notify_(long count) {",
      ]
    )
  }
}
