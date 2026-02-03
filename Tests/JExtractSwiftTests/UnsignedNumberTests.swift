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

final class UnsignedNumberTests {

  @Test(
    "Import: UInt16 (char)",
    arguments: [
      (
        JExtractGenerationMode.ffm,
        /* expected chunks */
        [
          """
          /**
           * {@snippet lang=c :
           * void swiftjava_SwiftModule_unsignedChar__(uint16_t arg)
           * }
           */
          private static class swiftjava_SwiftModule_unsignedChar__ {
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* arg: */SwiftValueLayout.SWIFT_UINT16
          );
          """,
          """
          public static void unsignedChar(@Unsigned char arg) {
            swiftjava_SwiftModule_unsignedChar__.call(arg);
          }
          """,
        ]
      ),
      (
        JExtractGenerationMode.jni,
        /* expected chunks */
        [
          """
          public static void unsignedChar(@Unsigned char arg) {
            SwiftModule.$unsignedChar(arg);
          }
          private static native void $unsignedChar(char arg);
          """,
        ]
      )
    ])
  func unsignedChar(mode: JExtractGenerationMode, expectedChunks: [String]) throws {
    try assertOutput(
      input: "public func unsignedChar(_ arg: UInt16)",
      mode, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: expectedChunks
    )
  }

  @Test(
    "Import: UInt32 (annotate)",
    arguments: [
      (
        JExtractGenerationMode.ffm,
        /* expected chunks */
        [
          """
          /**
           * {@snippet lang=c :
           * void swiftjava_SwiftModule_unsignedInt__(uint32_t arg)
           * }
           */
          private static class swiftjava_SwiftModule_unsignedInt__ {
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* arg: */SwiftValueLayout.SWIFT_UINT32
          );
          """,
          """
          public static void unsignedInt(@Unsigned int arg) {
            swiftjava_SwiftModule_unsignedInt__.call(arg);
          }
          """,
        ]
      ),
      (
        JExtractGenerationMode.jni,
        /* expected chunks */
        [
          """
          public static void unsignedInt(@Unsigned int arg) {
            SwiftModule.$unsignedInt(arg);
          }
          private static native void $unsignedInt(int arg);
          """,
        ]
      )
    ])
  func unsignedIntAnnotate(mode: JExtractGenerationMode, expectedChunks: [String]) throws {
    var config = Configuration()

    try assertOutput(
      input: "public func unsignedInt(_ arg: UInt32)",
      config: config,
      mode, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: expectedChunks
    )
  }

  @Test(
    "Import: return UInt32 (default)",
    arguments: [
      (
        JExtractGenerationMode.ffm,
        /* expected chunks */
        [
          """
          /**
           * {@snippet lang=c :
           * uint32_t swiftjava_SwiftModule_returnUnsignedInt(void)
           * }
           */
          private static class swiftjava_SwiftModule_returnUnsignedInt {
            private static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_UINT32
          );
          """,
          """
          @Unsigned
          public static int returnUnsignedInt() {
            return swiftjava_SwiftModule_returnUnsignedInt.call();
          }
          """,
        ]
      ),
      (
        JExtractGenerationMode.jni,
        /* expected chunks */
        [
          """
          @Unsigned
          public static int returnUnsignedInt() {
            return SwiftModule.$returnUnsignedInt();
          }
          private static native int $returnUnsignedInt();
          """,
        ]
      )
    ])
  func returnUnsignedIntDefault(mode: JExtractGenerationMode, expectedChunks: [String]) throws {
    let config = Configuration()

    try assertOutput(
      input: "public func returnUnsignedInt() -> UInt32",
      config: config,
      mode, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: expectedChunks
    )
  }

  @Test(
    "Import: return UInt64 (annotate)",
    arguments: [
      (
        JExtractGenerationMode.ffm,
        /* expected chunks */
        [
          """
          /**
           * {@snippet lang=c :
           * uint64_t swiftjava_SwiftModule_returnUnsignedLong(void)
           * }
           */
          private static class swiftjava_SwiftModule_returnUnsignedLong {
            private static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_UINT64
          );
          """,
          """
          @Unsigned
          public static long returnUnsignedLong() {
            return swiftjava_SwiftModule_returnUnsignedLong.call();
          }
          """,
        ]
      ),
      (
        JExtractGenerationMode.jni,
        /* expected chunks */
        [
          """
          @Unsigned
          public static long returnUnsignedLong() {
            return SwiftModule.$returnUnsignedLong();
          }
          private static native long $returnUnsignedLong();
          """,
        ]
      )
    ])
  func return_unsignedLong_annotate(mode: JExtractGenerationMode, expectedChunks: [String]) throws {
    var config = Configuration()

    try assertOutput(
      input: "public func returnUnsignedLong() -> UInt64",
      config: config,
      mode, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: expectedChunks
    )
  }

  @Test(
    "Import: take UInt64 (annotate)",
    arguments: [
      (
        JExtractGenerationMode.ffm,
        /* expected chunks */
        [
          """
          /**
           * {@snippet lang=c :
           * void swiftjava_SwiftModule_takeUnsignedLong_arg(uint64_t arg)
           * }
           */
          private static class swiftjava_SwiftModule_takeUnsignedLong_arg {
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* arg: */SwiftValueLayout.SWIFT_UINT64
          );
          """,
          """
          public static void takeUnsignedLong(@Unsigned long arg) {
            swiftjava_SwiftModule_takeUnsignedLong_arg.call(arg);
          }
          """,
        ]
      ),
      (
        JExtractGenerationMode.jni,
        /* expected chunks */
        [
          """
          public static void takeUnsignedLong(@Unsigned long arg) {
            SwiftModule.$takeUnsignedLong(arg);
          }
          private static native void $takeUnsignedLong(long arg);
          """,
        ]
      )
    ])
  func take_unsignedLong_annotate(mode: JExtractGenerationMode, expectedChunks: [String]) throws {
    var config = Configuration()

    try assertOutput(
      input: "public func takeUnsignedLong(arg: UInt64)",
      config: config,
      mode, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: expectedChunks
    )
  }

  @Test(
    "Import: take UInt64 return UInt32 (annotate)",
    arguments: [
      (
        JExtractGenerationMode.ffm,
        /* expected chunks */
        [
          """
          /**
           * {@snippet lang=c :
           * uint32_t swiftjava_SwiftModule_unsignedLong_first_second(uint64_t first, uint32_t second)
           * }
           */
          private static class swiftjava_SwiftModule_unsignedLong_first_second {
            private static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_UINT32
            /* first: */SwiftValueLayout.SWIFT_UINT64
            /* second: */SwiftValueLayout.SWIFT_UINT32
          );
          """,
          """
          @Unsigned
          public static int unsignedLong(@Unsigned long first, @Unsigned int second) {
            return swiftjava_SwiftModule_unsignedLong_first_second.call(first, second);
          }
          """,
        ]
      ),
      (
        JExtractGenerationMode.jni,
        /* expected chunks */
        [
          """
          @Unsigned
          public static int unsignedLong(@Unsigned long first, @Unsigned int second) {
            return SwiftModule.$unsignedLong(first, second);
          }
          private static native int $unsignedLong(long first, int second);
          """,
        ]
      ),
    ])
  func echo_unsignedLong_annotate(mode: JExtractGenerationMode, expectedChunks: [String]) throws {
    let config = Configuration()

    try assertOutput(
      input: "public func unsignedLong(first: UInt64, second: UInt32) -> UInt32",
      config: config,
      mode, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: expectedChunks
    )
  }
  
  @Test(
    "Import: take UInt return UInt (annotate)",
    arguments: [
      (
        JExtractGenerationMode.ffm,
        /* expected chunks */
        [
          """
          /**
           * {@snippet lang=c :
           * size_t swiftjava_SwiftModule_unsignedLong_first_second(size_t first, size_t second)
           * }
           */
          private static class swiftjava_SwiftModule_unsignedLong_first_second {
            private static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_INT
            /* first: */SwiftValueLayout.SWIFT_INT
            /* second: */SwiftValueLayout.SWIFT_INT
          );
          """,
          """
          @Unsigned
          public static long unsignedLong(@Unsigned long first, @Unsigned long second) throws SwiftIntegerOverflowException {
            if (SwiftValueLayout.has32bitSwiftInt) {
              if (first < 0 || first > 0xFFFFFFFFL) {
                throw new SwiftIntegerOverflowException("Parameter 'first' overflow: " + first);
              }
              if (second < 0 || second > 0xFFFFFFFFL) {
                throw new SwiftIntegerOverflowException("Parameter 'second' overflow: " + second);
              }
            }
            long _result$checked = swiftjava_SwiftModule_unsignedLong_first_second.call(first, second);
            if (SwiftValueLayout.has32bitSwiftInt) {
              if (_result$checked < 0 || _result$checked > 0xFFFFFFFFL) {
                throw new SwiftIntegerOverflowException("Return value overflow: " + _result$checked);
              }
            }
            return _result$checked;
          }
          """,
        ]
      ),
      (
        JExtractGenerationMode.jni,
        /* expected chunks */
        [
          """
          @Unsigned
          public static long unsignedLong(@Unsigned long first, @Unsigned long second) throws SwiftIntegerOverflowException {
            return SwiftModule.$unsignedLong(first, second);
          }
          private static native long $unsignedLong(long first, long second);
          """,
        ]
      ),
    ])
  func echo_uint_annotate(mode: JExtractGenerationMode, expectedChunks: [String]) throws {
    let config = Configuration()

    try assertOutput(
      input: "public func unsignedLong(first: UInt, second: UInt) -> UInt",
      config: config,
      mode, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: expectedChunks
    )
  }
}
