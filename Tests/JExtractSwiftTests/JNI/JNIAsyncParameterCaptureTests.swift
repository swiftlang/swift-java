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

/// The task closures of an async thunk are `sending`, so in the Swift 6 language mode they may only
/// capture the converted parameters through `nonisolated(unsafe)` copies.
@Suite
struct JNIAsyncParameterCaptureTests {

  @Test("Import: async function captures a value parameter's pointer (Swift)")
  func valueParameter_swift() throws {
    try assertOutput(
      input: """
        public struct Payload {
          public var value: Int64
        }

        public func async(p: Payload) async -> Int64
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__JLjava_util_concurrent_CompletableFuture_2")
        ...
        nonisolated(unsafe) let pUnsafeSendable$ = p$
        ...
        task = Task.immediate {
        ...
        let p$ = pUnsafeSendable$
        ...
        let swiftResult$ = await SwiftModule.async(p: p$.pointee)
        ...
        task = Task {
        ...
        let p$ = pUnsafeSendable$
        ...
        let swiftResult$ = await SwiftModule.async(p: p$.pointee)
        """
      ]
    )
  }

  @Test("Import: async function captures an optional class parameter's pointer (Swift)")
  func optionalClassParameter_swift() throws {
    try assertOutput(
      input: """
        public class MyClass { }

        public func async(c: MyClass?) async -> Int64
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__JLjava_util_concurrent_CompletableFuture_2")
        ...
        nonisolated(unsafe) let cUnsafeSendable$ = c$
        ...
        task = Task.immediate {
        ...
        let c$ = cUnsafeSendable$
        """
      ]
    )
  }

  @Test("Import: async function captures a protocol parameter's existential (Swift)")
  func protocolParameter_swift() throws {
    try assertOutput(
      input: """
        public protocol Named {
          func name() -> String
        }

        public func async(n: some Named) async -> String
        """,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__Ljava_lang_Object_2Ljava_util_concurrent_CompletableFuture_2")
        ...
        #if swift(>=6)
        nonisolated(unsafe) var nswiftObjectUnsafeSendable$ = nswiftObject$
        #else
        nonisolated(unsafe) let nswiftObjectUnsafeSendable$ = nswiftObject$
        #endif
        ...
        task = Task.immediate {
        ...
        let nswiftObject$ = nswiftObjectUnsafeSendable$
        ...
        let swiftResult$ = await SwiftModule.async(n: nswiftObject$)
        """
      ]
    )
  }

  @Test("Import: async function with primitive parameters captures nothing extra (Swift)")
  func primitiveParameters_swift() throws {
    try assertOutput(
      input: "public func async(i: Int64, s: String) async -> Int64",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024async__JLjava_lang_String_2Ljava_util_concurrent_CompletableFuture_2")
        ...
        """
      ],
      notExpectedChunks: [
        "UnsafeSendable$"
      ]
    )
  }
}
