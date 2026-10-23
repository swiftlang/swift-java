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
struct JNIMainActorTests {
  @Test("Synchronous main actor functions check isolation", arguments: ["MainActor", "_Concurrency.MainActor"])
  func globalFunction_swift(attribute: String) throws {
    try assertOutput(
      input: "@\(attribute) public func answer() -> Int64 { 42 }",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @MainActor
        @_cdecl("Java_com_example_swift_SwiftModule__00024answer__")
        ...
        MainActor.preconditionIsolated()
        return SwiftModule.answer().getJNILocalRefValue(in: environment)
        """
      ],
      notExpectedChunks: ["Task.immediate"]
    )
  }

  @Test("Synchronous main actor functions retain synchronous Java signatures")
  func globalFunction_java() throws {
    try assertOutput(
      input: "@MainActor public func answer() -> Int64 { 42 }",
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static long answer() {
          return SwiftModule.$answer();
        }
        """
      ],
      notExpectedChunks: ["CompletableFuture", "java.util.concurrent.Future"]
    )
  }

  @Test(
    "Main actor type members check isolation",
    arguments: [
      ("public init() {}", "K.init()"),
      ("public func hello() {}", "selfPointer$.pointee.hello()"),
      ("public static func hello() {}", "K.hello()"),
      ("public var value: Int64 { 42 }", "selfPointer$.pointee.value.getJNILocalRefValue(in: environment)"),
      ("public var value: Int64 { get { 0 } set {} }", "selfPointer$.pointee.value = Int64(fromJNI: newValue, in: environment)"),
      ("public subscript(index: Int64) -> Int64 { index }", "selfPointer$.pointee[Int64(fromJNI: index, in: environment)].getJNILocalRefValue(in: environment)"),
    ]
  )
  func typeMember_swift(member: String, call: String) throws {
    try assertOutput(
      input: "@MainActor public final class K { \(member) }",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "@MainActor\n@_cdecl(", "MainActor.preconditionIsolated()",
        call,
      ],
      notExpectedChunks: ["Task.immediate"]
    )
  }

  @Test(
    "Explicitly isolated members check isolation",
    arguments: [
      "public final class K { @MainActor public func hello() {} }",
      "public final class K { @MainActor public var value: Int64 { 42 } }",
      "public final class K {}\nextension K { @MainActor public func hello() {} }",
      "@MainActor public final class K {}\nextension K { public func hello() {} }",
      "public final class K {}\n@MainActor extension K { public func hello() {} }",
    ]
  )
  func isolatedMember_swift(source: String) throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      expectedChunks: ["@MainActor\n@_cdecl(", "MainActor.preconditionIsolated()"],
      notExpectedChunks: ["Task.immediate"]
    )
  }

  @Test(
    "Nonisolated members do not check main actor isolation",
    arguments: [
      "public nonisolated init() {}",
      "public nonisolated func hello() {}",
      "public nonisolated var value: Int64 { 42 }",
      "public nonisolated(unsafe) var value: Int64 { 42 }",
    ]
  )
  func nonisolatedMember_swift(member: String) throws {
    try assertOutput(
      input: "@MainActor public final class K { \(member) }",
      .jni,
      .swift,
      expectedChunks: ["@_cdecl("],
      notExpectedChunks: ["MainActor.preconditionIsolated()", "@MainActor\n@_cdecl(", "Task.immediate"]
    )
  }

  @Test("Generic opener requirements and witnesses preserve main actor isolation")
  func genericMember_swift() throws {
    try assertOutput(
      input: "@MainActor public struct K<T> { public var value: Int64 { 42 } }",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        protocol _SwiftModule_K_opener {
          @MainActor
          static func _get_value(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong
        }
        """,
        """
        extension K: _SwiftModule_K_opener {
          @MainActor
          static func _get_value(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
        """,
      ]
    )
  }

  @Test("Throwing main actor calls translate exceptions inside the isolation check")
  func throwingFunction_swift() throws {
    try assertOutput(
      input: "@MainActor public func answer() throws -> Int64 { 42 }",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        MainActor.preconditionIsolated()
        do {
          return try SwiftModule.answer().getJNILocalRefValue(in: environment)
        } catch {
          environment.throwSwiftErrorAsJava(error)
          return 0
        }
        """
      ]
    )
  }

  @Test("Reference-valued JNI results stay inside an isolated thunk")
  func stringResult_swift() throws {
    try assertOutput(
      input: "@MainActor public func greeting() -> String { \"Hello\" }",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @MainActor
        @_cdecl("Java_com_example_swift_SwiftModule__00024greeting__")
        public func Java_com_example_swift_SwiftModule__00024greeting__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jstring? {
          MainActor.preconditionIsolated()
          return SwiftModule.greeting().getJNILocalRefValue(in: environment)
        }
        """
      ],
      notExpectedChunks: ["MainActor.assumeIsolated"]
    )
  }

  @Test("Asynchronous main actor functions keep their asynchronous downcalls")
  func asyncFunction_swift() throws {
    try assertOutput(
      input: "@MainActor public func answer() async -> Int64 { 42 }",
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        task = Task.immediate {
        ...
        let swiftResult$ = await SwiftModule.answer()
        """
      ],
      notExpectedChunks: ["MainActor.preconditionIsolated()", "@MainActor\n@_cdecl("]
    )
  }

  @Test("Asynchronous main actor functions retain future-returning Java signatures")
  func asyncFunction_java() throws {
    try assertOutput(
      input: "@MainActor public func answer() async -> Int64 { 42 }",
      .jni,
      .java,
      expectedChunks: ["public static java.util.concurrent.CompletableFuture<java.lang.Long> answer() {"]
    )
  }
}
