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

/// Closure interfaces get a default `invoke` method, so Kotlin can call a closure as `handler()`.
@Suite
struct JNIClosureInvokeTests {
  let source =
    """
    public final class Notifier {
      public init() {}
      public func onMessage(_ handler: @escaping (String) -> Void) {}
      public func format(_ f: @escaping (String, Int64) -> String) {}
      public func double(_ f: (Int64) -> Int64) -> Int64 { f(2) }
    }
    """

  @Test
  func interfacesForwardInvokeToApply() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        public interface handler {
          void apply(java.lang.String _0);

          default void invoke(java.lang.String _0) {
            apply(_0);
          }
        }
        """,
        """
        public interface f {
          java.lang.String apply(java.lang.String _0, long _1);

          default java.lang.String invoke(java.lang.String _0, long _1) {
            return apply(_0, _1);
          }
        }
        """,
        // A closure `java.util.function` covers keeps that interface.
        "java.util.function.LongUnaryOperator",
      ]
    )
  }

  @Test
  func swiftCallsApply() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public func apply(_ _0: String)",
        "javaInterface_handler$.apply(_0)",
      ],
      notExpectedChunks: [
        "invoke"
      ]
    )
  }
}
