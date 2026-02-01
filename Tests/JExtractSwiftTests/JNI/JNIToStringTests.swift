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
import SwiftJavaConfigurationShared

@Suite
struct JNIToStringTests {
  let source =
    """
    public struct MyType {}
    """

  @Test("JNI toString (Java)")
  func toString_java() throws {
    try assertOutput(
      input: source,
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public String toString() {
          return $toString(this.$memoryAddress());
        }
        """,
        """
        private static native java.lang.String $toString(long selfPointer);
        """
      ]
    )
  }

  @Test("JNI toString (Swift)")
  func toString_swift() throws {
    try assertOutput(
      input: source,
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyType__00024toString__J")
        public func Java_com_example_swift_MyType__00024toString__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jstring? {
          ...
          return String(describing: self$.pointee).getJNIValue(in: environment)
        }
        """,
      ]
    )
  }

  @Test("JNI toDebugString (Java)")
  func toDebugString_java() throws {
    try assertOutput(
      input: source,
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public String toDebugString() {
          return $toDebugString(this.$memoryAddress());
        }
        """,
      ]
    )
  }

  @Test("JNI toDebugString (Swift)")
  func toDebugString_swift() throws {
    try assertOutput(
      input: source,
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyType__00024toDebugString__J")
        public func Java_com_example_swift_MyType__00024toDebugString__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jstring? {
          ...
          return String(reflecting: self$.pointee).getJNIValue(in: environment)
        }
        """,
      ]
    )
  }
}
