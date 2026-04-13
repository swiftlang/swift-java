//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
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
        public record Null() implements Case {
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
        public record Instanceof(java.lang.String arg0) implements Case {
        """,
        """
        private static native Instanceof._NativeParameters $getAsInstanceof(long selfPointer);
        """,
      ]
    )

    try assertOutput(
      input: text,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyEnumWithValue__00024getAsInstanceof__J")
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
        public record Default() implements Case {
        """,
      ]
    )
  }
}
