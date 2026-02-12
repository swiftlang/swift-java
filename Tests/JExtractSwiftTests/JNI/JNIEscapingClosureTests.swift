//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
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
struct JNIEscapingClosureTests {
  let source =
    """
    public class CallbackManager {
      private var callback: (() -> Void)?
      
      public init() {}
      
      public func setCallback(callback: @escaping () -> Void) {
        self.callback = callback
      }
      
      public func triggerCallback() {
        callback?()
      }
      
      public func clearCallback() {
        callback = nil
      }
    }

    public func delayedExecution(closure: @escaping (Int64) -> Int64, input: Int64) -> Int64 {
      // Simplified for testing - would normally be async
      return closure(input)
    }
    """

  @Test
  func escapingEmptyClosure_javaBindings() throws {
    let simpleSource =
      """
      public func setCallback(callback: @escaping () -> Void) {}
      """

    try assertOutput(
      input: simpleSource,
      .jni,
      .java,
      expectedChunks: [
        """
        public static class setCallback {
          @FunctionalInterface
          public interface callback {
            void apply();
          }
        }
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func setCallback(callback: @escaping () -> Void)
         * }
         */
        public static void setCallback(com.example.swift.SwiftModule.setCallback.callback callback) {
          SwiftModule.$setCallback(callback);
        }
        """,
      ]
    )
  }

  @Test
  func escapingClosureWithParameters_javaBindings() throws {
    let source =
      """
      public func delayedExecution(closure: @escaping (Int64) -> Int64) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        public static class delayedExecution {
          @FunctionalInterface
          public interface closure {
            long apply(long _0);
          }
        }
        """
      ]
    )
  }

  @Test
  func escapingClosure_swiftThunks() throws {
    let source =
      """
      public func setCallback(callback: @escaping () -> Void) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let closureContext_callback$ = JavaObjectHolder(object: callback, environment: environment)
        """
      ]
    )
  }

  @Test
  func nonEscapingClosure_stillWorks() throws {
    let source =
      """
      public func call(closure: () -> Void) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        @FunctionalInterface
        public interface closure {
          void apply();
        }
        """
      ]
    )
  }
}
