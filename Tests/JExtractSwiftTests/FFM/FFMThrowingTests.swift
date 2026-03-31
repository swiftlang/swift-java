//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
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
struct FFMThrowingTests {
  let throwingSource = """
    public func throwingVoid() throws
    public func throwingReturn(x: Int64) throws -> Int64
    """

  @Test
  func throwingVoid_swiftThunks() throws {
    try assertOutput(
      input: throwingSource,
      .ffm,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_throwingVoid")
        public func swiftjava_SwiftModule_throwingVoid(_ result$throws: UnsafeMutablePointer<UnsafeMutableRawPointer?>) {
          do {
            try throwingVoid()
          } catch {
            result$throws.pointee = Unmanaged.passRetained(SwiftJavaError(error)).toOpaque()
          }
        }
        """
      ],
    )
  }

  @Test
  func throwingReturn_swiftThunks() throws {
    try assertOutput(
      input: throwingSource,
      .ffm,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_throwingReturn_x")
        public func swiftjava_SwiftModule_throwingReturn_x(_ x: Int64, _ result$throws: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int64 {
          do {
            return try throwingReturn(x: x)
          } catch {
            result$throws.pointee = Unmanaged.passRetained(SwiftJavaError(error)).toOpaque()
            return 0
          }
        }
        """
      ],
    )
  }

  @Test
  func throwingVoid_javaBindings() throws {
    try assertOutput(
      input: throwingSource,
      .ffm,
      .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_throwingVoid(void **result$throws)
         * }
         */
        private static class swiftjava_SwiftModule_throwingVoid {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* result$throws: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_throwingVoid");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment result$throws) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(result$throws);
              }
              HANDLE.invokeExact(result$throws);
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
         * public func throwingVoid() throws
         * }
         */
        public static void throwingVoid() throws SwiftJavaErrorException {
          try(var arena$ = Arena.ofConfined()) {
            MemorySegment result$throws = arena$.allocate(ValueLayout.ADDRESS);
            result$throws.set(ValueLayout.ADDRESS, 0, MemorySegment.NULL);
            swiftjava_SwiftModule_throwingVoid.call(result$throws);
            if (!result$throws.get(ValueLayout.ADDRESS, 0).equals(MemorySegment.NULL)) {
              throw new SwiftJavaErrorException(result$throws.get(ValueLayout.ADDRESS, 0), AllocatingSwiftArena.ofAuto());
            }
          }
        }
        """,
      ],
    )
  }

  @Test
  func throwingReturn_javaBindings() throws {
    try assertOutput(
      input: throwingSource,
      .ffm,
      .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * int64_t swiftjava_SwiftModule_throwingReturn_x(int64_t x, void **result$throws)
         * }
         */
        private static class swiftjava_SwiftModule_throwingReturn_x {
          private static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_INT64,
            /* x: */SwiftValueLayout.SWIFT_INT64,
            /* result$throws: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_throwingReturn_x");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static long call(long x, java.lang.foreign.MemorySegment result$throws) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(x, result$throws);
              }
              return (long) HANDLE.invokeExact(x, result$throws);
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
         * public func throwingReturn(x: Int64) throws -> Int64
         * }
         */
        public static long throwingReturn(long x) throws SwiftJavaErrorException {
          try(var arena$ = Arena.ofConfined()) {
            MemorySegment result$throws = arena$.allocate(ValueLayout.ADDRESS);
            result$throws.set(ValueLayout.ADDRESS, 0, MemorySegment.NULL);
            var result$ = (long) swiftjava_SwiftModule_throwingReturn_x.call(x, result$throws);
            if (!result$throws.get(ValueLayout.ADDRESS, 0).equals(MemorySegment.NULL)) {
              throw new SwiftJavaErrorException(result$throws.get(ValueLayout.ADDRESS, 0), AllocatingSwiftArena.ofAuto());
            }
            return result$;
          }
        }
        """,
      ],
    )
  }

  let stringReturnSource = """
    public func greeting() -> String
    """

  @Test
  func stringReturn_swiftThunks() throws {
    try assertOutput(
      input: stringReturnSource,
      .ffm,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_greeting")
        public func swiftjava_SwiftModule_greeting() -> UnsafeMutablePointer<Int8> {
          return _swiftjava_stringToCString(greeting())
        }
        """
      ],
    )
  }

  @Test
  func stringReturn_javaBindings() throws {
    try assertOutput(
      input: stringReturnSource,
      .ffm,
      .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * int8_t *swiftjava_SwiftModule_greeting(void)
         * }
         */
        private static class swiftjava_SwiftModule_greeting {
          private static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_greeting");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static java.lang.foreign.MemorySegment call() {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall();
              }
              return (java.lang.foreign.MemorySegment) HANDLE.invokeExact();
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
         * public func greeting() -> String
         * }
         */
        public static java.lang.String greeting() {
          return SwiftStrings.fromCString(swiftjava_SwiftModule_greeting.call());
        }
        """,
      ],
    )
  }
}
