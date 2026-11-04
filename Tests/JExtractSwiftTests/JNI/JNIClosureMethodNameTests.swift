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

/// `closureMethodName` names the method of closure interfaces, so Kotlin can call a closure as `handler()`.
@Suite
struct JNIClosureMethodNameTests {
  let source =
    """
    public final class Notifier {
      public init() {}
      public func onMessage(_ handler: @escaping (String) -> Void) {}
      public func double(_ f: (Int64) -> Int64) -> Int64 { f(2) }
    }
    """

  var config: Configuration {
    var config = Configuration()
    config.closureMethodName = "invoke"
    return config
  }

  @Test
  func javaInterfacesUseTheName() throws {
    try assertOutput(
      input: source,
      config: config,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "void invoke(java.lang.String _0);",
        // A closure `java.util.function` covers gets its own interface, so it is called the same way.
        "long invoke(long _0);",
      ],
      notExpectedChunks: [
        " apply(",
        "LongUnaryOperator",
      ]
    )
  }

  @Test
  func swiftCallsTheName() throws {
    try assertOutput(
      input: source,
      config: config,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public func invoke(_ _0: String)",
        "javaInterface_handler$.invoke(_0)",
        #"environment.interface.GetMethodID(environment, class$, "invoke", "(J)J")!"#,
      ],
      notExpectedChunks: [
        "func apply(",
        ".apply(",
      ]
    )
  }

  @Test
  func applyIsTheDefault() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "void apply(java.lang.String _0);",
        "java.util.function.LongUnaryOperator",
      ]
    )
  }
}
