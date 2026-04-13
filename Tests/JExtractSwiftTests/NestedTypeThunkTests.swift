//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
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

final class NestedTypeThunkTests {
  let input =
    """
    import Swift

    public class Outer {
      public class Inner {
        public var value: Int
        public init(value: Int) {}
        public func describe() -> String { "" }
      }
    }
    """

  @Test("Nested type thunks: dots replaced with underscores in cdecl names")
  func thunk_nestedType_swift() throws {
    try assertOutput(
      input: input,
      .ffm,
      .swift,
      swiftModuleName: "FakeModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        // The getType thunk should use Outer_Inner, not Outer.Inner
        """
        @_cdecl("swiftjava_getType_FakeModule_Outer_Inner")
        public func swiftjava_getType_FakeModule_Outer_Inner() -> UnsafeMutableRawPointer /* Any.Type */ {
          return unsafeBitCast(Outer.Inner.self, to: UnsafeMutableRawPointer.self)
        }
        """,
        // Member thunks should also use Outer_Inner
        """
        @_cdecl("swiftjava_FakeModule_Outer_Inner_init_value")
        public func swiftjava_FakeModule_Outer_Inner_init_value(_ value: Int, _ _result: UnsafeMutableRawPointer) {
          _result.assumingMemoryBound(to: Outer.Inner.self).initialize(to: Outer.Inner(value: value))
        }
        """,
        """
        @_cdecl("swiftjava_FakeModule_Outer_Inner_value$get")
        public func swiftjava_FakeModule_Outer_Inner_value$get(_ self: UnsafeRawPointer) -> Int {
          return self.assumingMemoryBound(to: Outer.Inner.self).pointee.value
        }
        """,
      ]
    )
  }

  @Test("Nested type Java bindings: class names use underscores not dots")
  func thunk_nestedType_java() throws {
    try assertOutput(
      input: input,
      .ffm,
      .java,
      swiftModuleName: "FakeModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        // Java class name for the inner class descriptor should not contain dots
        "swiftjava_FakeModule_Outer_Inner_init_value",
        "swiftjava_FakeModule_Outer_Inner_value$get",
        "swiftjava_FakeModule_Outer_Inner_value$set",
      ],
      // Must NOT contain the dotted version
      notExpectedChunks: [
        "swiftjava_FakeModule_Outer.Inner"
      ]
    )
  }
}
