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
struct JNIIsolatedParameterTests {

  static let source = """
    public actor MyActor {
      public init() {}
    }
    public class Service {
      public init() {}
      public func run(on actor: isolated MyActor) throws -> Int { 0 }
    }
    """

  @Test("Import: isolated throws -> Int (Java) is converted to a future")
  func isolatedParameter_java() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public java.util.concurrent.CompletableFuture<java.lang.Long> run(MyActor actor) {
        """,
        """
        private static native void $run(long actor, long selfPointer, java.util.concurrent.CompletableFuture<java.lang.Long> result_future);
        """,
      ]
    )
  }

  @Test("Import: isolated throws -> Int (Swift) is awaited inside a Task")
  func isolatedParameter_swift() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        task = Task.immediate {
        ...
        do {
          let swiftResult$ = try await selfPointer$.pointee.run(on: actor$.pointee)
        """
      ],
      notExpectedChunks: [
        """
        do {
          let swiftResult$ = try selfPointer$.pointee.run(on: actor$.pointee)
        """
      ]
    )
  }
}
