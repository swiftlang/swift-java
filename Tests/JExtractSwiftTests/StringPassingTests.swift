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
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .trace

    try assertOutput(
      st, input: class_interfaceFile, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func writeString(string: String) -> Int
         * }
         */
        public static long writeString(java.lang.String string) {
            var mh$ = swiftjava___FakeModule_writeString_string.HANDLE;
            try(var arena$ = Arena.ofConfined()) {
                var string$ = SwiftKit.toCString(string, arena$);
                if (SwiftKit.TRACE_DOWNCALLS) {
                    SwiftKit.traceDowncall(string$);
                }
                return (long) mh$.invokeExact(string$);
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
      ])
  }
}
