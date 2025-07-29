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

final class UnsignedNumberTests {

  @Test("Import: UInt8")
  func unsignedByte() throws {
    try assertOutput(
      input: "public func unsignedByte(_ arg: UInt8)",
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_unsignedByte__(uint8_t arg)
         * }
         */
        private static class swiftjava_SwiftModule_unsignedByte__ {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
          /* arg: */SwiftValueLayout.SWIFT_UINT8
        );
        """,
        """
        public static void unsignedByte(org.swift.swiftkit.core.primitives.UnsignedByte arg) {
          swiftjava_SwiftModule_unsignedByte__.call(UnsignedNumbers.toPrimitive(arg));
        }
        """,
      ]
    )
  }

  @Test("Import: UInt16")
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
        public static void unsignedChar(char arg) {
          swiftjava_SwiftModule_unsignedChar__.call(UnsignedNumbers.toPrimitive(arg));
        }
        """,
      ]
    )
  }

  @Test("Import: UInt32")
  func unsignedInt() throws {
    try assertOutput(
      input: "public func unsignedInt(_ arg: UInt32)",
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
        public static void unsignedInt(org.swift.swiftkit.core.primitives.UnsignedInteger arg) {
          swiftjava_SwiftModule_unsignedInt__.call(UnsignedNumbers.toPrimitive(arg));
        }
        """,
      ]
    )
  }

  @Test("Import: return UInt32")
  func returnUnsignedInt() throws {
    try assertOutput(
      input: "public func returnUnsignedInt() -> UInt32",
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
        public static org.swift.swiftkit.core.primitives.UnsignedInteger returnUnsignedInt() {
          return UnsignedInteger.fromIntBits(swiftjava_SwiftModule_returnUnsignedInt.call());
        }
        """,
      ]
    )
  }

  @Test("Import: UInt64")
  func unsignedLong() throws {
    try assertOutput(
      input: "public func unsignedLong(_ arg: UInt64)",
      .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_unsignedLong__(uint64_t arg)
         * }
         */
        private static class swiftjava_SwiftModule_unsignedLong__ {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
          /* arg: */SwiftValueLayout.SWIFT_UINT64
        );
        """,
        """
        public static void unsignedLong(org.swift.swiftkit.core.primitives.UnsignedLong arg) {
          swiftjava_SwiftModule_unsignedLong__.call(UnsignedNumbers.toPrimitive(arg));
        }
        """,
      ]
    )
  }

  @Test("Import: return UInt64")
  func returnUnsignedLong() throws {
    try assertOutput(
      input: "public func returnUnsignedLong() -> UInt64",
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
        public static org.swift.swiftkit.core.primitives.UnsignedLong returnUnsignedLong() {
          return UnsignedLong.fromLongBits(swiftjava_SwiftModule_returnUnsignedLong.call());
        }
        """,
      ]
    )
  }

}
