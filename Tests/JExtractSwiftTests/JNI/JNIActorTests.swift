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

@Suite
struct JNIActor1MethodsTests {

  static let source = """
    public actor K {
      public init() {}
      public func hello() {}
    }

    extension K {
      public func hi() {}
    }
    """

  @Test("Import: actor method is imported as a future (Java)")
  func actorMethod_java() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public java.util.concurrent.CompletableFuture<java.lang.Void> hello() {
          java.util.concurrent.CompletableFuture<java.lang.Void> future$ = new java.util.concurrent.CompletableFuture<java.lang.Void>();
          K.$hello(this.$memoryAddress(), future$);
          return future$.thenApply((futureResult$) -> {
            return futureResult$;
          }
          );
        }
        """,
        """
        private static native void $hello(long selfPointer, java.util.concurrent.CompletableFuture<java.lang.Void> result_future);
        """,
      ],
      notExpectedChunks: [
        "public void hello() {",
        "private static native void $hello(long selfPointer);",
      ]
    )
  }

  @Test("Import: actor method awaits the actor (Swift)")
  func actorMethod_swift() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_K__00024hello__JLjava_util_concurrent_CompletableFuture_2")
        ...
        task = Task.immediate {
        ...
        await selfPointer$.pointee.hello()
        """
      ]
    )
  }

  @Test("Import: actor extension method is imported as a future (Java)")
  func actorExtensionMethod_java() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public java.util.concurrent.CompletableFuture<java.lang.Void> hi() {
          java.util.concurrent.CompletableFuture<java.lang.Void> future$ = new java.util.concurrent.CompletableFuture<java.lang.Void>();
          K.$hi(this.$memoryAddress(), future$);
          return future$.thenApply((futureResult$) -> {
            return futureResult$;
          }
          );
        }
        """,
        """
        private static native void $hi(long selfPointer, java.util.concurrent.CompletableFuture<java.lang.Void> result_future);
        """,
      ],
      notExpectedChunks: [
        "public void hi() {",
        "private static native void $hi(long selfPointer);",
      ]
    )
  }

  @Test("Import: actor extension method awaits the actor (Swift)")
  func actorExtensionMethod_swift() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_K__00024hi__JLjava_util_concurrent_CompletableFuture_2")
        ...
        task = Task.immediate {
        ...
        await selfPointer$.pointee.hi()
        """
      ]
    )
  }
}
