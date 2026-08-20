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
      public nonisolated func sync() {}
    }

    extension K {
      public func hi() {}
      public nonisolated func syncInExtension() {}
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

  @Test("Import: nonisolated actor method stays synchronous (Java)")
  func nonisolatedMethod_java() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public void sync() {
          K.$sync(this.$memoryAddress());
        }
        """,
        """
        private static native void $sync(long selfPointer);
        """,
        """
        public void syncInExtension() {
          K.$syncInExtension(this.$memoryAddress());
        }
        """,
        """
        private static native void $syncInExtension(long selfPointer);
        """,
      ],
      notExpectedChunks: [
        "public java.util.concurrent.CompletableFuture<java.lang.Void> sync() {",
        "public java.util.concurrent.CompletableFuture<java.lang.Void> syncInExtension() {",
      ]
    )
  }

  @Test("Import: nonisolated actor method does not await the actor (Swift)")
  func nonisolatedMethod_swift() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_K__00024sync__J")
        ...
        selfPointer$.pointee.sync()
        """
      ],
      notExpectedChunks: [
        "await selfPointer$.pointee.sync()",
        "await selfPointer$.pointee.syncInExtension()",
      ]
    )
  }
}
