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
struct JNIGenericTypeTests {
  let genericFile =
    #"""
    public struct MyID<T> {
      public var rawValue: T
      public init(_ rawValue: T) {
        self.rawValue = rawValue  
      }
      public var description: String {
        "\(rawValue)"
      }
    }
    """#

  @Test
  func generateJavaClass() throws {
    try assertOutput(
      input: genericFile,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public final class MyID implements JNISwiftInstance {
        """,
        """
        private final long t0MetaPointer;
        """,
        """
        public java.lang.String getDescription() {
          return MyID.$getDescription(this.$memoryAddress(), this.t0MetaPointer);
        }
        private static native java.lang.String $getDescription(long self, long t0MetaPointer);
        """,
        """
        private static native java.lang.String $toString(long selfPointer, long t0MetaPointer);
        """,
        """
        private static native long $typeMetadataAddressDowncall(long t0MetaPointer);
        @Override
        public long $typeMetadataAddress() {
          long self$ = this.$memoryAddress();
          if (CallTraces.TRACE_DOWNCALLS) {
            CallTraces.traceDowncall("MyID.$typeMetadataAddress",
                "this", this,
                "self", self$);
          }
          return MyID.$typeMetadataAddressDowncall(t0MetaPointer);
        }
        """
      ]
    )
  }
}
