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
      @concurrent public func concurrently() {}
      @concurrent public func concurrentlyAsync() async {}
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
          org.swift.swiftkit.core.SwiftAsyncResultSink<java.lang.Void, java.lang.Void> resultSink$ = org.swift.swiftkit.core.SwiftAsyncResultSink.create((futureResult$) -> {
            return futureResult$;
          }
          );
          K.$hello(this.$memoryAddress(), resultSink$);
          return resultSink$.future();
        }
        """,
        """
        private static native void $hello(long selfPointer, org.swift.swiftkit.core.SwiftAsyncResultSink<java.lang.Void, java.lang.Void> result_sink);
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
        @_cdecl("Java_com_example_swift_K__00024hello__JLorg_swift_swiftkit_core_SwiftAsyncResultSink_2")
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
          org.swift.swiftkit.core.SwiftAsyncResultSink<java.lang.Void, java.lang.Void> resultSink$ = org.swift.swiftkit.core.SwiftAsyncResultSink.create((futureResult$) -> {
            return futureResult$;
          }
          );
          K.$hi(this.$memoryAddress(), resultSink$);
          return resultSink$.future();
        }
        """,
        """
        private static native void $hi(long selfPointer, org.swift.swiftkit.core.SwiftAsyncResultSink<java.lang.Void, java.lang.Void> result_sink);
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
        @_cdecl("Java_com_example_swift_K__00024hi__JLorg_swift_swiftkit_core_SwiftAsyncResultSink_2")
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

  @Test("Import: @concurrent actor method stays synchronous (Java)")
  func concurrentMethod_java() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public void concurrently() {
          K.$concurrently(this.$memoryAddress());
        }
        """,
        """
        private static native void $concurrently(long selfPointer);
        """,
      ],
      notExpectedChunks: [
        "public java.util.concurrent.CompletableFuture<java.lang.Void> concurrently() {"
      ]
    )
  }

  @Test("Import: @concurrent actor method does not await the actor (Swift)")
  func concurrentMethod_swift() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_K__00024concurrently__J")
        ...
        selfPointer$.pointee.concurrently()
        """
      ],
      notExpectedChunks: [
        "await selfPointer$.pointee.concurrently()"
      ]
    )
  }

  @Test("Import: @concurrent async actor method is imported as a future (Java)")
  func concurrentAsyncMethod_java() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public java.util.concurrent.CompletableFuture<java.lang.Void> concurrentlyAsync() {
          org.swift.swiftkit.core.SwiftAsyncResultSink<java.lang.Void, java.lang.Void> resultSink$ = org.swift.swiftkit.core.SwiftAsyncResultSink.create((futureResult$) -> {
            return futureResult$;
          }
          );
          K.$concurrentlyAsync(this.$memoryAddress(), resultSink$);
          return resultSink$.future();
        }
        """,
        """
        private static native void $concurrentlyAsync(long selfPointer, org.swift.swiftkit.core.SwiftAsyncResultSink<java.lang.Void, java.lang.Void> result_sink);
        """,
      ],
      notExpectedChunks: [
        "public void concurrentlyAsync() {",
        "private static native void $concurrentlyAsync(long selfPointer);",
      ]
    )
  }

  @Test("Import: @concurrent async actor method is awaited (Swift)")
  func concurrentAsyncMethod_swift() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_K__00024concurrentlyAsync__JLorg_swift_swiftkit_core_SwiftAsyncResultSink_2")
        ...
        task = Task.immediate {
        ...
        await selfPointer$.pointee.concurrentlyAsync()
        """
      ]
    )
  }
}

@Suite
struct JNIActorPropertyIsolationTests {
  static let source = """
    public actor Record {
      public nonisolated let identifier: Int64
      public nonisolated var label: Int64 { 7 }
      public nonisolated(unsafe) var unsafeValue: Int64
      public var isolatedValue: Int64
    }
    """

  @Test
  func javaAccessors() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .java,
      expectedChunks: [
        "public long getIdentifier() {",
        "public long getLabel() {",
        "public long getUnsafeValue() {",
        "public void setUnsafeValue(long newValue) {",
        "public java.util.concurrent.CompletableFuture<java.lang.Long> getIsolatedValue() {",
        "public java.util.concurrent.CompletableFuture<java.lang.Void> setIsolatedValue(long newValue) {",
      ]
    )
  }

  @Test
  func swiftAccessors() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .swift,
      expectedChunks: [
        "return selfPointer$.pointee.identifier.getJNILocalRefValue(in: environment)",
        "return selfPointer$.pointee.label.getJNILocalRefValue(in: environment)",
        "selfPointer$.pointee.unsafeValue = Int64(fromJNI: newValue, in: environment)",
        "let swiftResult$ = await selfPointer$.pointee.isolatedValue",
      ],
      notExpectedChunks: [
        "await selfPointer$.pointee.identifier",
        "await selfPointer$.pointee.label",
        "await selfPointer$.pointee.unsafeValue",
      ]
    )
  }
}
