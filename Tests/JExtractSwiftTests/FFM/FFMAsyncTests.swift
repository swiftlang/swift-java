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
struct FFMAsyncTests {

  @Test("Import: async -> Void (Java, CompletableFuture)")
  func completableFuture_asyncVoid_java() throws {
    try assertOutput(
      input: "public func asyncVoid() async",
      .ffm,
      .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_asyncVoid(void (*async$completion)(void))
         * }
         */
        private static class swiftjava_SwiftModule_asyncVoid {
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func asyncVoid() async
         * }
         */
        public static java.util.concurrent.CompletableFuture<java.lang.Void> asyncVoid() {
          java.util.concurrent.CompletableFuture<java.lang.Void> future$ = new java.util.concurrent.CompletableFuture<java.lang.Void>();
          MemorySegment $async$completion = swiftjava_SwiftModule_asyncVoid.$async$completion.toUpcallStub(() -> {
            future$.complete(null);
          }, Arena.ofAuto());
          swiftjava_SwiftModule_asyncVoid.call($async$completion);
          return future$;
        }
        """,
      ]
    )
  }

  @Test("Import: async -> Void (Swift, CompletableFuture)")
  func completableFuture_asyncVoid_swift() throws {
    try assertOutput(
      input: "public func asyncVoid() async",
      .ffm,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_asyncVoid")
        public func swiftjava_SwiftModule_asyncVoid(_ async$completion: @convention(c) () -> ()) {
        """,
        """
            task = Task.immediate {
              await asyncVoid()
              async$completion()
            }
        """,
        """
          if task == nil {
            task = Task {
              await asyncVoid()
              async$completion()
            }
          }
        """,
      ]
    )
  }

  @Test("Import: async throws -> Void (Java, CompletableFuture)")
  func completableFuture_asyncThrowsVoid_java() throws {
    try assertOutput(
      input: "public func asyncThrowsVoid() async throws",
      .ffm,
      .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_asyncThrowsVoid(void (*async$completion)(void), void (*async$error)(void *))
         * }
         */
        private static class swiftjava_SwiftModule_asyncThrowsVoid {
        """,
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func asyncThrowsVoid() async throws
         * }
         */
        public static java.util.concurrent.CompletableFuture<java.lang.Void> asyncThrowsVoid() {
          java.util.concurrent.CompletableFuture<java.lang.Void> future$ = new java.util.concurrent.CompletableFuture<java.lang.Void>();
          MemorySegment $async$completion = swiftjava_SwiftModule_asyncThrowsVoid.$async$completion.toUpcallStub(() -> {
            future$.complete(null);
          }, Arena.ofAuto());
          MemorySegment $async$error = swiftjava_SwiftModule_asyncThrowsVoid.$async$error.toUpcallStub((error$) -> {
            if (!error$.equals(MemorySegment.NULL)) {
              future$.completeExceptionally(new SwiftJavaErrorException(error$, AllocatingSwiftArena.ofAuto()));
            }
          }, Arena.ofAuto());
          swiftjava_SwiftModule_asyncThrowsVoid.call($async$completion, $async$error);
          return future$;
        }
        """,
      ]
    )
  }

  @Test("Import: async throws -> Void (Swift, CompletableFuture)")
  func completableFuture_asyncThrowsVoid_swift() throws {
    try assertOutput(
      input: "public func asyncThrowsVoid() async throws",
      .ffm,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_asyncThrowsVoid")
        public func swiftjava_SwiftModule_asyncThrowsVoid(_ async$completion: @convention(c) () -> (), _ async$error: @convention(c) (UnsafeMutableRawPointer?) -> ()) {
        """,
        """
              do {
                try await asyncThrowsVoid()
                async$completion()
              } catch {
                let errorPtr = Unmanaged.passRetained(SwiftJavaError(error)).toOpaque()
                async$error(errorPtr)
              }
        """,
      ]
    )
  }

  @Test("Import: async -> Int64 (Java, CompletableFuture)")
  func completableFuture_asyncSum_java() throws {
    try assertOutput(
      input: "public func asyncSum(a: Int64, b: Int64) async -> Int64",
      .ffm,
      .java,
      expectedChunks: [
        """
        public static java.util.concurrent.CompletableFuture<java.lang.Long> asyncSum(long a, long b) {
          java.util.concurrent.CompletableFuture<java.lang.Long> future$ = new java.util.concurrent.CompletableFuture<java.lang.Long>();
          MemorySegment $async$completion = swiftjava_SwiftModule_asyncSum_a_b.$async$completion.toUpcallStub((result$) -> {
            future$.complete(result$);
          }, Arena.ofAuto());
          swiftjava_SwiftModule_asyncSum_a_b.call(a, b, $async$completion);
          return future$;
        }
        """,
      ]
    )
  }

  @Test("Import: async -> Int64 (Swift, CompletableFuture)")
  func completableFuture_asyncSum_swift() throws {
    try assertOutput(
      input: "public func asyncSum(a: Int64, b: Int64) async -> Int64",
      .ffm,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_asyncSum_a_b")
        public func swiftjava_SwiftModule_asyncSum_a_b(_ a: Int64, _ b: Int64, _ async$completion: @convention(c) (Int64) -> ()) {
        """,
        """
              let async$result = await asyncSum(a: a, b: b)
              async$completion(async$result)
        """,
      ]
    )
  }
}
