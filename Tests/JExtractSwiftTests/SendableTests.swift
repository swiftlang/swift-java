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

@Suite
final class SendableTests {
  let source =
    """
    public struct SendableStruct: Sendable {}
    """

  @Test("Import: Sendable struct (ffm)")
  func sendableStruct_ffm() throws {

    try assertOutput(
      input: source,
      .ffm,
      .java,
      expectedChunks: [
        """
        @ThreadSafe // Sendable
        public final class SendableStruct extends FFMSwiftInstance implements SwiftValue {
          static final java.lang.String LIB_NAME = "SwiftModule";
          static final Arena LIBRARY_ARENA = Arena.ofAuto();
        """
      ]
    )
  }

  @Test("Import: Sendable struct (jni)")
  func sendableStruct_jni() throws {

    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        @ThreadSafe // Sendable
        public final class SendableStruct implements JNISwiftInstance {
          static final java.lang.String LIB_NAME = "SwiftModule";
        """
      ]
    )
  }

  @Test("Import: Sendable escaping closure (jni)")
  func sendableEscapingClosure_jni() throws {
    let closureSource =
      """
      public func onEvent(_ f: @escaping @Sendable (Int64) -> Void) {}
      """

    try assertOutput(
      input: closureSource,
      .jni,
      .java,
      expectedChunks: [
        """
        public static class onEvent {
          /** Corresponds to the Swift closure parameter of type {@code @escaping @Sendable (Int64) -> Void}. */
          @ThreadSafe // Sendable
          @FunctionalInterface
          public interface f {
            void apply(long _0);
          }
        }
        """
      ]
    )
  }

  @Test("Import: Sendable escaping closure Swift wrapper (jni)")
  func sendableEscapingClosureSwift_jni() throws {
    let closureSource =
      """
      public func onEvent(_ f: @escaping @Sendable (Int64) -> Void) {}
      """

    try assertOutput(
      input: closureSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @JavaInterface("com.example.swift.SwiftModule$onEvent$f")
        public struct JavaSwiftModule_onEvent_f: @unchecked Sendable {
          @JavaMethod
          public func apply(_ _0: Int64)
        }
        """,
        """
        return { @Sendable _0 in
          javaInterface_f$.apply(_0)
        }
        """,
      ]
    )
  }

  @Test("Import: Sendable escaping closure (ffm)")
  func sendableEscapingClosure_ffm() throws {
    let closureSource =
      """
      public func onEvent(_ f: @escaping @Sendable (Int64) -> Void) {}
      """

    try assertOutput(
      input: closureSource,
      .ffm,
      .java,
      expectedChunks: [
        """
        public static class onEvent {
          @ThreadSafe // Sendable
          @FunctionalInterface
          public interface f extends swiftjava_SwiftModule_onEvent__.$f.Function {}
          private static MemorySegment $toUpcallStub(f fi, Arena arena) {
            return swiftjava_SwiftModule_onEvent__.$f.toUpcallStub(fi, arena);
          }
        }
        """
      ]
    )
  }

  @Test("Import: Sendable non-escaping closure (jni)")
  func sendableNonEscapingClosure_jni() throws {
    let closureSource =
      """
      public func performAction(_ f: @Sendable (Int64) -> Void) {}
      """

    try assertOutput(
      input: closureSource,
      .jni,
      .java,
      expectedChunks: [
        """
        public static class performAction {
          /** Corresponds to the Swift closure parameter of type {@code @Sendable (Int64) -> Void}. */
          @ThreadSafe // Sendable
          @FunctionalInterface
          public interface f {
            void apply(long _0);
          }
        }
        """
      ]
    )
  }

  @Test("Import: Sendable non-escaping closure (ffm)")
  func sendableNonEscapingClosure_ffm() throws {
    let closureSource =
      """
      public func performAction(_ f: @Sendable (Int64) -> Void) {}
      """

    try assertOutput(
      input: closureSource,
      .ffm,
      .java,
      expectedChunks: [
        """
        public static class performAction {
          @ThreadSafe // Sendable
          @FunctionalInterface
          public interface f extends swiftjava_SwiftModule_performAction__.$f.Function {}
          private static MemorySegment $toUpcallStub(f fi, Arena arena) {
            return swiftjava_SwiftModule_performAction__.$f.toUpcallStub(fi, arena);
          }
        }
        """
      ]
    )
  }

  @Test("Import: Sendable closure does not use known functional interface (jni)")
  func sendableClosure_doesNotUseKnownFunctionalInterface_jni() throws {
    let closureSource =
      """
      public func runStandard(closure: () -> Void) {}
      public func runSendable(closure: @Sendable () -> Void) {}
      """

    try assertOutput(
      input: closureSource,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static void runStandard(java.lang.Runnable closure) {
          SwiftModule.$runStandard(closure);
        }
        """,
        """
        public static class runSendable {
          /** Corresponds to the Swift closure parameter of type {@code @Sendable () -> Void}. */
          @ThreadSafe // Sendable
          @FunctionalInterface
          public interface closure {
            void apply();
          }
        }
        """,
        """
        public static void runSendable(com.example.swift.SwiftModule.runSendable.closure closure) {
          SwiftModule.$runSendable(closure);
        }
        """,
      ]
    )

    try assertOutput(
      input: closureSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024runStandard__Ljava_lang_Runnable_2")
        public func Java_com_example_swift_SwiftModule__00024runStandard__Ljava_lang_Runnable_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.runStandard(closure: {
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "run", "()V")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = []
            environment.interface.CallVoidMethodA(environment, closure, methodID$, arguments$)
          }
          )
        }
        """,
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024runSendable__Lcom_example_swift_SwiftModule_00024runSendable_00024closure_2")
        public func Java_com_example_swift_SwiftModule__00024runSendable__Lcom_example_swift_SwiftModule_00024runSendable_00024closure_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, closure: jobject?) {
          SwiftModule.runSendable(closure: { @Sendable in
            let class$ = environment.interface.GetObjectClass(environment, closure)
            let methodID$ = environment.interface.GetMethodID(environment, class$, "apply", "()V")!
            environment.interface.DeleteLocalRef(environment, class$)
            let arguments$: [jvalue] = []
            environment.interface.CallVoidMethodA(environment, closure, methodID$, arguments$)
          }
          )
        }
        """,
      ]
    )
  }

}
