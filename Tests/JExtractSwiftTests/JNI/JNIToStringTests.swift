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
import SwiftJavaConfigurationShared
import Testing

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
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public java.lang.String toString() {
          return SwiftObjects.toString(this.$memoryAddress(), this.$typeMetadataAddress());
        }
        """
      ]
    )
  }

  @Test("JNI toDebugString (Java)")
  func toDebugString_java() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public java.lang.String toDebugString() {
          return SwiftObjects.toDebugString(this.$memoryAddress(), this.$typeMetadataAddress());
        }
        """
      ]
    )
  }
}
