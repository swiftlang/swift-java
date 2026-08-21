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
         * void swiftjava_SwiftModule_asyncVoid(void **$async$completion, void **$async$error)
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
          try (var arena$ = org.swift.swiftkit.core.AllocatingSwiftArena.ofConfined()) {
            java.util.concurrent.CompletableFuture future$ = new java.util.concurrent.CompletableFuture();
            java.lang.foreign.MemorySegment $async$completion = swiftjava_SwiftModule_asyncVoid.$async$completion.toUpcallStub((result$) -> {
              future$.complete(null);
            }, java.lang.foreign.Arena.ofAuto());
            swiftjava_SwiftModule_asyncVoid.call($async$completion);
            return future$;
          }
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
        public func swiftjava_SwiftModule_asyncVoid(_ $async$completion: (@convention(c) () -> Void)?) {
          Task.immediate {
            await asyncVoid()
            $async$completion?()
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
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func asyncThrowsVoid() async throws
         * }
         */
        public static java.util.concurrent.CompletableFuture<java.lang.Void> asyncThrowsVoid() {
          try (var arena$ = org.swift.swiftkit.core.AllocatingSwiftArena.ofConfined()) {
            java.util.concurrent.CompletableFuture future$ = new java.util.concurrent.CompletableFuture();
            java.lang.foreign.MemorySegment $async$completion = swiftjava_SwiftModule_asyncThrowsVoid.$async$completion.toUpcallStub((result$) -> {
              future$.complete(null);
            }, java.lang.foreign.Arena.ofAuto());
            java.lang.foreign.MemorySegment $async$error = swiftjava_SwiftModule_asyncThrowsVoid.$async$error.toUpcallStub((error$) -> {
              if (!error$.equals(java.lang.foreign.MemorySegment.NULL)) {
                future$.completeExceptionally(new org.swift.swiftkit.ffm.generated.SwiftJavaErrorException(error$, org.swift.swiftkit.core.AllocatingSwiftArena.ofAuto()));
              }
            }, java.lang.foreign.Arena.ofAuto());
            swiftjava_SwiftModule_asyncThrowsVoid.call($async$completion, $async$error);
            return future$;
          }
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
        public func swiftjava_SwiftModule_asyncThrowsVoid(_ $async$completion: (@convention(c) () -> Void)?, _ $async$error: (@convention(c) (UnsafePointer<CChar>) -> Void)?) {
          Task.immediate {
            do {
              try await asyncThrowsVoid()
              $async$completion?()
            } catch {
              let errorString = String(describing: error)
              errorString.withCString { errorCString in
                  $async$error?(errorCString)
              }
            }
          }
        }
        """,
      ]
    )
  }
}
