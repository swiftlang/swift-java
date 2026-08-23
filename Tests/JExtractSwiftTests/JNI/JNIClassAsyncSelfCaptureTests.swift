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
import SwiftJavaConfigurationShared
import Testing

@Suite
struct JNIAsyncSelfCaptureTests {

  @Test("Import: class async method captures converted self pointer (Swift)")
  func classAsyncMethod_swift() throws {
    try assertOutput(
      input: """
        public class MyClass {
          public func compute() async -> Int64 { 42 }
        }
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyClass__00024compute__JLjava_util_concurrent_CompletableFuture_2")
        ...
        nonisolated(unsafe) let selfPointerSendable$ = selfPointer$
        ...
        task = Task.immediate {
        ...
        let selfPointer$ = selfPointerSendable$
        ...
        let swiftResult$ = await selfPointer$.pointee.compute()
        """
      ]
    )
  }

  @Test("Import: protocol box async method captures loaded existential (Swift)")
  func protocolBoxAsyncMethod_swift() throws {
    try assertOutput(
      input: """
        public protocol Worker {
          func work() async -> Int64
        }
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_WorkerBox__00024work__JJLjava_util_concurrent_CompletableFuture_2")
        ...
        nonisolated(unsafe) let selfPointerExistentialSendable$ = selfPointerExistential$
        ...
        task = Task.immediate {
        ...
        let selfPointerExistential$ = selfPointerExistentialSendable$
        ...
        let swiftResult$ = await selfPointerExistential$.work()
        """
      ],
      notExpectedChunks: [
        "nonisolated(unsafe) let selfPointerSendable$",
        "nonisolated(unsafe) let selfTypePointerSendable$",
      ]
    )
  }

  @Test("Import: generic class async method captures only self pointer (Swift)")
  func genericClassAsyncMethod_swift() throws {
    try assertOutput(
      input: """
        public class Box<T> {
          public func compute() async -> Int64 { 42 }
        }
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        extension Box: _SwiftModule_Box_opener {
        ...
        nonisolated(unsafe) let selfPointerSendable$ = selfPointer$
        ...
        task = Task.immediate {
        ...
        let selfPointer$ = selfPointerSendable$
        ...
        let swiftResult$ = await selfPointer$.pointee.compute()
        """
      ],
      notExpectedChunks: [
        "selfTypePointerSendable$",
      ]
    )
  }
}
