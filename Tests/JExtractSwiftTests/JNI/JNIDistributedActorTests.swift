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
          java.util.concurrent.CompletableFuture<java.lang.Void> future$ = new java.util.concurrent.CompletableFuture<java.lang.Void>();
          D.$hi(this.$memoryAddress(), future$);
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
        @_cdecl("Java_com_example_swift_D__00024hi__JLjava_util_concurrent_CompletableFuture_2")
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
          let exception = catchEnvironment.interface.NewObjectA(catchEnvironment, _JNIMethodIDCache.Exception.class, _JNIMethodIDCache.Exception.constructWithMessage, [String(describing: error).getJValue(in: catchEnvironment)])
          _ = catchEnvironment.interface.CallBooleanMethodA(catchEnvironment, globalFuture, _JNIMethodIDCache.CompletableFuture.completeExceptionally, [jvalue(l: exception)])
        }
        """,
      ]
    )
  }
}
