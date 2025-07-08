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

final class StringPassingTests {
  let class_interfaceFile =
    """
    public func writeString(string: String) -> Int { 
      return string.count
    }
    """

  @Test("Import: public func writeString(string: String) -> Int")
  func method_helloWorld() throws {
    try assertOutput(
      input: class_interfaceFile, .ffm, .java,
      swiftModuleName: "__FakeModule",
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * ptrdiff_t swiftjava___FakeModule_writeString_string(const int8_t *string)
         * }
         */
        private static class swiftjava___FakeModule_writeString_string {
          private static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_INT,
            /* string: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            __FakeModule.findOrThrow("swiftjava___FakeModule_writeString_string");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static long call(java.lang.foreign.MemorySegment string) {
            try {
              if (SwiftRuntime.TRACE_DOWNCALLS) {
                SwiftRuntime.traceDowncall(string);
              }
              return (long) HANDLE.invokeExact(string);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
        }
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func writeString(string: String) -> Int
         * }
         */
        public static long writeString(java.lang.String string) {
            try(var arena$ = Arena.ofConfined()) {
                return swiftjava___FakeModule_writeString_string.call(SwiftRuntime.toCString(string, arena$));
            }
        }
        """
      ])
  }
}
