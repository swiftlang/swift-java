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

import JExtractSwiftLib
import Testing

final class SendableTests {
  let source =
    """
    public struct SendableStruct: Sendable {}
    """


  @Test("Import: Sendable struct (ffm)")
  func sendableStruct_ffm() throws {

    try assertOutput(
      input: source, .ffm, .java,
      expectedChunks: [
        """
        @ThreadSafe // Sendable
        public final class SendableStruct extends FFMSwiftInstance implements SwiftValue {
          static final String LIB_NAME = "SwiftModule";
          static final Arena LIBRARY_ARENA = Arena.ofAuto();
        """,
      ]
    )
  }

  @Test("Import: Sendable struct (jni)")
  func sendableStruct_jni() throws {

    try assertOutput(
      input: source, .jni, .java,
      expectedChunks: [
        """
        @ThreadSafe // Sendable
        public final class SendableStruct implements JNISwiftInstance {
          static final String LIB_NAME = "SwiftModule";
        """,
      ]
    )
  }

}
