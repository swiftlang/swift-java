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

import CodePrinting
import JExtractSwiftLib
import SwiftExtract
import SwiftJavaConfigurationShared
import Testing

@Suite
struct JNIErrorTests {
  let source = """
    public enum NetworkError: Error {
      case offline
      case timeout(seconds: Int64)
    }

    public struct ParseError: Error {
      public var message: String
    }

    public final class StorageError: Error {
      public init() {}
    }

    public struct LateError {}
    extension LateError: Error {}

    public func fetch() throws(NetworkError) {}
    """

  @Test
  func errorTypes_javaClassHeaders() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @SuppressWarnings("serial")
        public final class NetworkError extends org.swift.swiftkit.core.SwiftError {
        """,
        """
        @SuppressWarnings("serial")
        public final class ParseError extends org.swift.swiftkit.core.SwiftError {
        """,
        """
        @SuppressWarnings("serial")
        public final class StorageError extends org.swift.swiftkit.core.SwiftError {
        """,
        """
        @SuppressWarnings("serial")
        public final class LateError extends org.swift.swiftkit.core.SwiftError {
        """,
      ]
    )
  }

  @Test
  func errorTypes_keepsStringMessage() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        "public java.lang.String getMessage() {"
      ]
    )
  }

  @Test
  func errorTypes_swiftConformance() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        extension NetworkError: _JNIThrowableError {
          public func _makeJavaThrowable(in environment: JNIEnvironment) -> JNITypes.jthrowable? {
            _JNIBridge_NetworkError.toJavaObject(self, in: environment)
          }
        }
        """,
        """
        extension ParseError: _JNIThrowableError {
          public func _makeJavaThrowable(in environment: JNIEnvironment) -> JNITypes.jthrowable? {
            _JNIBridge_ParseError.toJavaObject(self, in: environment)
          }
        }
        """,
        """
        extension StorageError: _JNIThrowableError {
          public func _makeJavaThrowable(in environment: JNIEnvironment) -> JNITypes.jthrowable? {
            _JNIBridge_StorageError.toJavaObject(self, in: environment)
          }
        }
        """,
        """
        extension LateError: _JNIThrowableError {
          public func _makeJavaThrowable(in environment: JNIEnvironment) -> JNITypes.jthrowable? {
            _JNIBridge_LateError.toJavaObject(self, in: environment)
          }
        }
        """,
      ]
    )
  }

  @Test
  func errorClassHierarchy_conformanceOnRootOnly() throws {
    let input = """
      public class BaseError: Error {
        public init() {}
      }

      public class SubError: BaseError {}

      public func failBase() throws(BaseError) {}
      """

    try assertOutput(
      input: input,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        extension BaseError: _JNIThrowableError {
          public func _makeJavaThrowable(in environment: JNIEnvironment) -> JNITypes.jthrowable? {
            _JNIBridge_BaseError.toJavaObject(self, in: environment)
          }
        }
        """
      ],
      // SubError inherits BaseError's conformance; redeclaring it would not compile
      notExpectedChunks: [
        "extension SubError: _JNIThrowableError"
      ]
    )

    try assertOutput(
      input: input,
      .jni,
      .java,
      expectedChunks: [
        "public static void failBase() throws BaseError {"
      ]
    )
  }

  @Test
  func typedThrows_javaSignature() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        "public static void fetch() throws NetworkError {"
      ]
    )
  }
}
