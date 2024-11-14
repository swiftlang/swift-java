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

import JExtractSwift
import Testing

final class VariableImportTests {
  let class_interfaceFile =
    """
    // swift-interface-format-version: 1.0
    // swift-compiler-version: Apple Swift version 6.0 effective-5.10 (swiftlang-6.0.0.7.6 clang-1600.0.24.1)
    // swift-module-flags: -target arm64-apple-macosx15.0 -enable-objc-interop -enable-library-evolution -module-name MySwiftLibrary
    import Darwin.C
    import Darwin
    import Swift
    import _Concurrency
    import _StringProcessing
    import _SwiftConcurrencyShims

    public class MySwiftClass {
      public var counterInt: Int
    }
    """

  @Test("Import: var counter: Int")
  func variable_int() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "FakeModule"
    )
    st.log.logLevel = .error

    try assertOutput(
      st, input: class_interfaceFile, .java,
      detectChunkByInitialLines: 7,
      expectedChunks:
      [
        """
        private static class counterInt {
          public static final FunctionDescriptor DESC_GET =     FunctionDescriptor.of(
              /* -> */SWIFT_INT,
              SWIFT_POINTER
          );
          public static final MemorySegment ADDR_GET =
          FakeModule.findOrThrow("swiftjava_FakeModule_MySwiftClass_counterInt");

          public static final MethodHandle HANDLE_GET = Linker.nativeLinker().downcallHandle(ADDR_GET, DESC_GET);
          public static final FunctionDescriptor DESC_SET =     FunctionDescriptor.ofVoid(
              SWIFT_INT,
              SWIFT_POINTER
          );
          public static final MemorySegment ADDR_SET =
              FakeModule.findOrThrow("swiftjava_FakeModule_MySwiftClass_counterInt");

          public static final MethodHandle HANDLE_SET = Linker.nativeLinker().downcallHandle(ADDR_SET, DESC_SET);
        }
        """,
        """
        /**
         * Function descriptor for:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public static FunctionDescriptor counterInt$get$descriptor() {
            return counterInt.DESC_GET;
        }
        """,
        """
        /**
         * Downcall method handle for:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public static MethodHandle counterInt$get$handle() {
            return counterInt.HANDLE_GET;
        }
        """,
        """
        /**
         * Address for:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
        */
        public static MemorySegment counterInt$get$address() {
            return counterInt.ADDR_GET;
        }
        """,
        """
        /**
         * Function descriptor for:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public static FunctionDescriptor counterInt$set$descriptor() {
            return counterInt.DESC_SET;
        }
        """
        ,
        """
        /**
         * Downcall method handle for:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public static MethodHandle counterInt$set$handle() {
            return counterInt.HANDLE_SET;
        }
        """,
        """
        /**
         * Address for:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public static MemorySegment counterInt$set$address() {
            return counterInt.ADDR_SET;
        }
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public static long getCounterInt(java.lang.foreign.MemorySegment self$) {
            var mh$ = counterInt.HANDLE_GET;
            try {
                if (SwiftKit.TRACE_DOWNCALLS) {
                    SwiftKit.traceDowncall(self$);
                }
                return (long) mh$.invokeExact(self$);
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public long getCounterInt() {
          return (long) getCounterInt($memorySegment());
        }
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public static void setCounterInt(long newValue, java.lang.foreign.MemorySegment self$) {
          var mh$ = counterInt.HANDLE_SET;
          try {
            if (SwiftKit.TRACE_DOWNCALLS) {
               SwiftKit.traceDowncall(newValue, self$);
            }
             mh$.invokeExact(newValue, self$);
          } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
          }
        }
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public var counterInt: Int
         * }
         */
        public void setCounterInt(long newValue) {
           setCounterInt(newValue, $memorySegment());
        }
        """
      ]
    )
  }
}
