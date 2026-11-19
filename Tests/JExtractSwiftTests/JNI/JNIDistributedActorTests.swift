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
struct JNIDistributedActorTests {

  static let source = """
    public distributed actor D {
      public distributed func hi() {}
    }
    """

  @Test("Import distributed actor: distributed func is imported as a future (Java)")
  func distributedFuncMethod_java() throws {
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
          D.$hi(this.$memoryAddress(), resultSink$);
          return resultSink$.future();
        }
        """,
        """
        private static native void $hi(long selfPointer, org.swift.swiftkit.core.SwiftAsyncResultSink<java.lang.Void, java.lang.Void> result_sink);
        """,
      ],
      notExpectedChunks: [
        "public void hi() {",
        "throws Exception",
      ]
    )
  }

  @Test("Import distributed actor: distributed func call is awaited with try (Swift)")
  func distributedFuncMethod_swift() throws {
    try assertOutput(
      input: Self.source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_D__00024hi__JLorg_swift_swiftkit_core_SwiftAsyncResultSink_2")
        ...
        task = Task.immediate {
        ...
        do {
        ...
        try await selfPointer$.pointee.hi()
        """,
        """
        catch {
          let catchEnvironment = try! JavaVirtualMachine.shared().environment()
          if SwiftJavaRuntimeSupport.SwiftAsyncResultSink.isDone(globalResultSink, in: catchEnvironment) { return }
          let exception = catchEnvironment.makeJavaThrowable(for: error)
          SwiftJavaRuntimeSupport.SwiftAsyncResultSink.fail(self: globalResultSink, exception, in: catchEnvironment)
        }
        """,
      ]
    )
  }
}
