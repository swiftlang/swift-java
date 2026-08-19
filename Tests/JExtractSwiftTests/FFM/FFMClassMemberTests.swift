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
struct FFMClassMemberTests {
  let source = """
    public class MyClass {
      public class func classMethod() -> Int64 { 42 }
      public class var classVariable: Int64 { 7 }
    }
    """

  @Test
  func classMethod_javaBindings() throws {
    try assertOutput(
      input: source,
      .ffm,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public class func classMethod() -> Int64
         * }
         */
        public static long classMethod() {
          return swiftjava_SwiftModule_MyClass_classMethod.call();
        }
        """
      ]
    )
  }

  @Test
  func classVariable_javaBindings() throws {
    try assertOutput(
      input: source,
      .ffm,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public class var classVariable: Int64
         * }
         */
        public static long getClassVariable() {
          return swiftjava_SwiftModule_MyClass_classVariable$get.call();
        }
        """
      ]
    )
  }

  @Test
  func classMembers_swiftThunks() throws {
    try assertOutput(
      input: source,
      .ffm,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_MyClass_classMethod")
        public func swiftjava_SwiftModule_MyClass_classMethod() -> Int64 {
          return MyClass.classMethod()
        }
        """,
        """
        @_cdecl("swiftjava_SwiftModule_MyClass_classVariable$get")
        public func swiftjava_SwiftModule_MyClass_classVariable$get() -> Int64 {
          return MyClass.classVariable
        }
        """,
      ]
    )
  }
}
