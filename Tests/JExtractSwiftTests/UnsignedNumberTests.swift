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

  @Test("Import: UInt16 (char)")
  func unsignedChar() throws {
    try assertOutput(
      input: "public func unsignedChar(_ arg: UInt16)",
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
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
    )
  }

  @Test("Import: UInt32 (wrap)")
  func unsignedInt() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .wrapGuava

    try assertOutput(
      input: "public func unsignedInt(_ arg: UInt32)",
      config: config,
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
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
        public static void unsignedInt(com.google.common.primitives.UnsignedInteger arg) {
          swiftjava_SwiftModule_unsignedInt__.call(UnsignedNumbers.toPrimitive(arg));
        }
        """,
      ]
    )
  }

  @Test("Import: UInt32 (annotate)")
  func unsignedIntAnnotate() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .annotate

    try assertOutput(
      input: "public func unsignedInt(_ arg: UInt32)",
      config: config,
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
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
    )
  }

  @Test("Import: return UInt32 (default)")
  func returnUnsignedIntDefault() throws {
    let config = Configuration()

    try assertOutput(
      input: "public func returnUnsignedInt() -> UInt32",
      config: config,
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
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
    )
  }

  @Test("Import: return UInt64 (wrap)")
  func return_unsignedLongWrap() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .wrapGuava

    try assertOutput(
      input: "public func returnUnsignedLong() -> UInt64",
      config: config,
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
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
        public static com.google.common.primitives.UnsignedLong returnUnsignedLong() {
          return com.google.common.primitives.UnsignedLong.fromLongBits(swiftjava_SwiftModule_returnUnsignedLong.call());
        }
        """,
      ]
    )
  }

  @Test("Import: return UInt64 (annotate)")
  func return_unsignedLong_annotate() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .annotate

    try assertOutput(
      input: "public func returnUnsignedLong() -> UInt64",
      config: config,
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
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
    )
  }

  @Test("Import: take UInt64 (annotate)")
  func take_unsignedLong_annotate() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .annotate

    try assertOutput(
      input: "public func takeUnsignedLong(arg: UInt64)",
      config: config,
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
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
    )
  }

  @Test("Import: take UInt64 return UInt32 (annotate)")
  func echo_unsignedLong_annotate() throws {
    var config = Configuration()
    config.unsignedNumbersMode = .annotate

    try assertOutput(
      input: "public func unsignedLong(first: UInt64, second: UInt32) -> UInt32",
      config: config,
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
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
    )
  }
}
