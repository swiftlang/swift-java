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
struct JNIAsyncTests {

  @Test("Import: async -> Void (CompletableFuture)")
  func completableFuture_asyncVoid_java() throws {
    try assertOutput(
      input: "public func asyncVoid() async",
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func asyncVoid() async
         * }
         */
        public static java.util.concurrent.CompletableFuture<Void> asyncVoid() {
          return CompletableFuture.supplyAsync(() -> {
            SwiftModule.$asyncVoid();
            return null;
          }
          );
        }
        """,
        """
        private static native void $asyncVoid();
        """,
      ]
    )
  }

  @Test("Import: async throws -> Void (CompletableFuture)")
  func completableFuture_asyncThrowsVoid_java() throws {
    try assertOutput(
      input: "public func async() async throws",
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func async() async throws
         * }
         */
        public static java.util.concurrent.CompletableFuture<Void> async() {
          return CompletableFuture.supplyAsync(() -> {
            SwiftModule.$async();
            return null;
          }
          );
        }
        """,
        """
        private static native void $async();
        """,
      ]
    )
  }

  @Test("Import: (Int64) async -> Int64 (CompletableFuture)")
  func completableFuture_asyncIntToInt_java() throws {
    try assertOutput(
      input: "public func async(i: Int64) async -> Int64",
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func async(i: Int64) async -> Int64
         * }
         */
        public static java.util.concurrent.CompletableFuture<Long> async(long i) {
          return CompletableFuture.supplyAsync(() -> {
            return SwiftModule.$async(i);
          }
          );
        }
        """,
        """
        private static native long $async(long i);
        """,
      ]
    )
  }

  @Test("Import: (MyClass) async -> MyClass (CompletableFuture)")
  func completableFuture_asyncMyClassToMyClass_java() throws {
    try assertOutput(
      input: """
      class MyClass { }
      
      public func async(c: MyClass) async -> MyClass
      """,
      .jni, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func async(c: MyClass) async -> MyClass
         * }
         */
        public static java.util.concurrent.CompletableFuture<MyClass> async(MyClass c, SwiftArena swiftArena$) {
          return CompletableFuture.supplyAsync(() -> {
            return MyClass.wrapMemoryAddressUnsafe(SwiftModule.$async(c.$memoryAddress()), swiftArena$);
          }
          );
        }
        """,
        """
        private static native long $async(long c);
        """,
      ]
    )
  }
}
