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
    let st = Swift2JavaTranslator(
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .trace

    try assertOutput(
      st, input: class_interfaceFile, .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * ptrdiff_t swiftjava___FakeModule_writeString_string(const int8_t *string)
         * }
         */
        private static class swiftjava___FakeModule_writeString_string {
          public static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_INT,
            /* string: */SwiftValueLayout.SWIFT_POINTER
          );
          public static final MemorySegment ADDR =
            __FakeModule.findOrThrow("swiftjava___FakeModule_writeString_string");
          public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static long call(java.lang.foreign.MemorySegment string) {
            try {
              if (SwiftKit.TRACE_DOWNCALLS) {
                SwiftKit.traceDowncall(string);
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
                return swiftjava___FakeModule_writeString_string.call(SwiftKit.toCString(string, arena$));
            }
        }
        """
      ])
  }
}
