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

final class OptionalImportTests {
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

    // MANGLED NAME: $fake
    public func globalGetStringOptional() -> String?

    // MANGLED NAME: $fake
    public func globalGetIntOptional() -> Int?

    // MANGLED NAME: $fake
    public func globalGetFloatOptional() -> Float?

    // FIXME: Hack to allow us to translate "String", even though it's not
    // actually available
    // MANGLED NAME: $ss
    public class String {
    }
    """

  @Test("Import: public func globalGetIntOptional() -> Int?")
  func globalGetIntOptional() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .warning

    assertOutput(
      st,
      input: class_interfaceFile,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func globalGetIntOptional() -> Int?
         * }
         */
        public static java.util.OptionalLong globalGetIntOptional() {
            var mh$ = globalGetIntOptional.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall();
                }
                return (java.util.OptionalLong) mh$.invokeExact();
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
      ]
    )
  }

  @Test("Import: public func globalGetStringOptional() -> String?")
  func globalGetStringOptional() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .warning

    assertOutput(
      st,
      input: class_interfaceFile,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func globalGetStringOptional() -> String?
         * }
         */
        public static java.util.Optional<String> globalGetStringOptional() {
            var mh$ = globalGetStringOptional.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall();
                }
                return (java.util.Optional<String>) mh$.invokeExact();
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
      ]
    )
  }

  @Test("Import: public func globalGetFloatOptional() -> Float?")
  func globalGetFloatOptional() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .warning

    assertOutput(
      st,
      input: class_interfaceFile,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func globalGetFloatOptional() -> Float?
         * }
         */
        public static java.util.OptionalDouble globalGetFloatOptional() {
            var mh$ = globalGetFloatOptional.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall();
                }
                return (java.util.OptionalDouble) mh$.invokeExact();
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
      ]
    )
  }
}