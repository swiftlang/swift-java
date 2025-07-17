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

final class OptionalImportTests {
  let interfaceFile =
    """
    import Foundation
    
    public func receiveOptionalIntSugar(_ arg: Int?)
    public func receiveOptionalIntExplicit(_ arg: Optional<Int>)
    public func receiveOptionalDataProto(_ arg: (some DataProtocol)?))
    """


  @Test("Import Optionals: JavaBindings")
  func data_javaBindings() throws {

    try assertOutput(
      input: interfaceFile, .ffm, .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_receiveOptionalIntSugar__(const ptrdiff_t *arg)
         * }
         */
        private static class swiftjava_SwiftModule_receiveOptionalIntSugar__ {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* arg: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_receiveOptionalIntSugar__");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment arg) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(arg);
              }
              HANDLE.invokeExact(arg);
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
         * public func receiveOptionalIntSugar(_ arg: Int?)
         * }
         */
        public static void receiveOptionalIntSugar(OptionalLong arg) {
          try(var arena$ = Arena.ofConfined()) {
            swiftjava_SwiftModule_receiveOptionalIntSugar__.call(SwiftRuntime.toOptionalSegmentLong(arg, arena$));
          }
        }
        """,

        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_receiveOptionalIntExplicit__(const ptrdiff_t *arg)
         * }
         */
        private static class swiftjava_SwiftModule_receiveOptionalIntExplicit__ {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* arg: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_receiveOptionalIntExplicit__");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment arg) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(arg);
              }
              HANDLE.invokeExact(arg);
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
         * public func receiveOptionalIntExplicit(_ arg: Optional<Int>)
         * }
         */
        public static void receiveOptionalIntExplicit(OptionalLong arg) {
          try(var arena$ = Arena.ofConfined()) {
            swiftjava_SwiftModule_receiveOptionalIntExplicit__.call(SwiftRuntime.toOptionalSegmentLong(arg, arena$));
          }
        }
        """,


        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_receiveOptionalDataProto__(const void *arg)
         * }
         */
        private static class swiftjava_SwiftModule_receiveOptionalDataProto__ {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* arg: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_receiveOptionalDataProto__");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment arg) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(arg);
              }
              HANDLE.invokeExact(arg);
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
         * public func receiveOptionalDataProto(_ arg: (some DataProtocol)?)
         * }
         */
        public static void receiveOptionalDataProto(Optional<Data> arg) {
          swiftjava_SwiftModule_receiveOptionalDataProto__.call(SwiftRuntime.toOptionalSegmentInstance(arg));
        }
        """,
      ]
    )
  }
}
