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
import SwiftJavaConfigurationShared
import Testing

final class JNIUnsignedNumberTests {

  @Test("Import: UInt16 (char)")
  func jni_unsignedChar() throws {
    try assertOutput(
      input: "public func unsignedChar(_ arg: UInt16)",
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func unsignedChar(_ arg: UInt16)
         * }
         */
        public static void unsignedChar(@Unsigned char arg) {
          SwiftModule.$unsignedChar(arg);
        }
        """,
        """
        private static native void $unsignedChar(char arg);
        """,
      ]
    )
  }

  @Test("Import: UInt32 (annotate)")
  func jni_unsignedInt_annotate() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .annotate
    config.logLevel = .trace

    try assertOutput(
      input: "public func unsignedInt(_ arg: UInt32)",
      config: config,
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func unsignedInt(_ arg: UInt32)
         * }
         */
        public static void unsignedInt(@Unsigned int arg) {
          SwiftModule.$unsignedInt(arg);
        }
        private static native void $unsignedInt(int arg);
        """,
      ]
    )
  }

  @Test("Import: return UInt32 (default)")
  func jni_returnUnsignedIntDefault() throws {
    let config = Configuration()

    try assertOutput(
      input: "public func returnUnsignedInt() -> UInt32",
      config: config,
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func returnUnsignedInt() -> UInt32
         * }
         */
        @Unsigned
        public static int returnUnsignedInt() {
          return SwiftModule.$returnUnsignedInt();
        }
        private static native int $returnUnsignedInt();
        """,
      ]
    )
  }

  @Test("Import: return UInt64 (wrap, unsupported)")
  func jni_return_unsignedLongWrap() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .wrapGuava

    try assertOutput(
      input: "public func returnUnsignedLong() -> UInt64",
      config: config,
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        // we do not import in wrap mode
        """
        public final class SwiftModule {
          static final String LIB_NAME = "SwiftModule";

          static {
            System.loadLibrary(LIB_NAME);
          }

        }
        """,
      ]
    )
  }

  @Test("Import: take UInt64 return UInt32 (annotate)")
  func jni_echo_unsignedLong_annotate() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .annotate

    try assertOutput(
      input: "public func unsignedLong(first: UInt64, second: UInt32) -> UInt32",
      config: config,
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
          /**
           * Downcall to Swift:
           * {@snippet lang=swift :
           * public func unsignedLong(first: UInt64, second: UInt32) -> UInt32
           * }
           */
          @Unsigned
          public static int unsignedLong(@Unsigned long first, @Unsigned int second) {
            return SwiftModule.$unsignedLong(first, second);
          }
          private static native int $unsignedLong(long first, int second);
        """,
      ]
    )
  }
}
