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
          /** Corresponds to the Swift closure parameter of type {@code @escaping () -> Void}. */
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
          /** Corresponds to the Swift closure parameter of type {@code @escaping (Int64) -> Int64}. */
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
        let javaInterface_callback$ = JavaSwiftModule_setCallback_callback(javaThis: callback, environment: environment)
        """,
        """
        @JavaInterface("com.example.swift.SwiftModule$setCallback$callback")
        public struct JavaSwiftModule_setCallback_callback {
          @JavaMethod
          public func apply()
        }
        """,
      ]
    )
  }

  @Test
  func escapingClosure_swiftAndJavaSidesAgreeOnBinaryName() throws {
    let source =
      """
      public func setCallback(callback: @escaping () -> Void) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static class setCallback {
          /** Corresponds to the Swift closure parameter of type {@code @escaping () -> Void}. */
          @FunctionalInterface
          public interface callback {
            void apply();
          }
        }
        """
      ]
    )

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.SwiftModule$setCallback$callback")
        public struct JavaSwiftModule_setCallback_callback {
          @JavaMethod
          public func apply()
        }
        """
      ]
    )
  }

  @Test
  func escapingClosureWithParametersAndResult_swiftThunks() throws {
    let source =
      """
      public func delayedExecution(closure: @escaping (Int64) -> Int64) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.SwiftModule$delayedExecution$closure")
        public struct JavaSwiftModule_delayedExecution_closure {
          @JavaMethod
          public func apply(_ _0: Int64) -> Int64
        }
        """
      ]
    )
  }

  @Test
  func escapingClosure_issue328_StringToString() throws {
    // Repro of https://github.com/swiftlang/swift-java/issues/328
    let source =
      """
      public func approve(_ fee: @escaping (String) -> String) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.SwiftModule$approve$fee")
        public struct JavaSwiftModule_approve_fee {
          @JavaMethod
          public func apply(_ _0: String) -> String
        }
        """,
        """
        let javaInterface_fee$ = JavaSwiftModule_approve_fee(javaThis: fee, environment: environment)
        """,
      ]
    )
  }

  @Test
  func escapingClosure_onClassMethod() throws {
    let source =
      """
      public class CallbackManager {
        public init() {}
        public func setCallback(_ callback: @escaping () -> Void) {}
      }
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.CallbackManager$setCallback$callback")
        public struct JavaCallbackManager_setCallback_callback {
          @JavaMethod
          public func apply()
        }
        """
      ]
    )
  }

  @Test
  func escapingClosure_onNestedTypeMethod() throws {
    let source =
      """
      public class Outer {
        public class Inner {
          public init() {}
          public func run(_ cb: @escaping () -> Void) {}
        }
      }
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.Outer$Inner$run$cb")
        public struct JavaOuter_Inner_run_cb {
          @JavaMethod
          public func apply()
        }
        """
      ]
    )
  }

  @Test
  func escapingClosure_onSpecializedGenericTypeMethod() throws {
    let source =
      """
      public struct Fish {}
      public class Tank<T> {
        public init() {}
        public func subscribe(_ cb: @escaping () -> Void) {}
      }
      public typealias FishTank = Tank<Fish>
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.FishTank$subscribe$cb")
        public struct JavaFishTank_subscribe_cb {
          @JavaMethod
          public func apply()
        }
        """,
        """
        @JavaInterface("com.example.swift.Tank$subscribe$cb")
        public struct JavaTank_subscribe_cb {
          @JavaMethod
          public func apply()
        }
        """,
      ]
    )
  }

  @Test
  func escapingClosure_multipleClosuresOnOneFunction() throws {
    let source =
      """
      public func run(onSuccess: @escaping () -> Void, onFailure: @escaping (Int64) -> Void) {}
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.SwiftModule$run$onSuccess")
        public struct JavaSwiftModule_run_onSuccess {
          @JavaMethod
          public func apply()
        }
        """,
        """
        @JavaInterface("com.example.swift.SwiftModule$run$onFailure")
        public struct JavaSwiftModule_run_onFailure {
          @JavaMethod
          public func apply(_ _0: Int64)
        }
        """,
        "let javaInterface_onSuccess$ = JavaSwiftModule_run_onSuccess(javaThis: onSuccess, environment: environment)",
        "let javaInterface_onFailure$ = JavaSwiftModule_run_onFailure(javaThis: onFailure, environment: environment)",
      ]
    )
  }

  @Test
  func escapingClosure_sameParamNameOnDifferentMethods() throws {
    let source =
      """
      public class Bus {
        public init() {}
        public func register(callback: @escaping () -> Void) {}
        public func unregister(callback: @escaping () -> Void) {}
      }
      """

    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.Bus$register$callback")
        public struct JavaBus_register_callback {
          @JavaMethod
          public func apply()
        }
        """,
        """
        @JavaInterface("com.example.swift.Bus$unregister$callback")
        public struct JavaBus_unregister_callback {
          @JavaMethod
          public func apply()
        }
        """,
      ]
    )
  }
}
