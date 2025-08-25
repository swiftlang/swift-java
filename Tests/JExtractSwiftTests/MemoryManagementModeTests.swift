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
import SwiftJavaConfigurationShared
import Testing

@Suite
struct MemoryManagementModeTests {
  let text =
    """
    class MyClass {}
    
    public func f() -> MyClass
    """

  @Test
  func explicit() throws {
    var config = Configuration()
    config.memoryManagementMode = .explicit

    try assertOutput(
      input: text,
      config: config,
      .jni, .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func f() -> MyClass
         * }
         */
        public static MyClass f(SwiftArena swiftArena$) {
          return MyClass.wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena$);
        }
        """,
      ]
    )
  }

  @Test
  func allowGlobalAutomatic() throws {
    var config = Configuration()
    config.memoryManagementMode = .allowGlobalAutomatic

    try assertOutput(
      input: text,
      config: config,
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static MyClass f() {
          return f(SwiftMemoryManagement.GLOBAL_SWIFT_JAVA_ARENA);
        }
        """,
        """
        public static MyClass f(SwiftArena swiftArena$) {
          return MyClass.wrapMemoryAddressUnsafe(SwiftModule.$f(), swiftArena$);
        }
        """,
      ]
    )
  }
}
