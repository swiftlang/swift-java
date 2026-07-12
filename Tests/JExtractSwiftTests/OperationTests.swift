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

import Testing

@Suite
final class OperationsOverloadingTests {
  let input =
    """
    public struct MyVector2 {
        var x: Int
        var y: Int

        public static func + (lhs: MyVector2, rhs: MyVector2) -> MyVector2 {
            MyVector2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
        }
    }
    """

  @Test
  func operatorPlus_ffm_swiftThunks() throws {
    try assertOutput(
      input: input,
      .ffm,
      .swift,
      swiftModuleName: "FakeModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("swiftjava_FakeModule_MyVector2_plus_lhs_rhs")
        public func swiftjava_FakeModule_MyVector2_plus_lhs_rhs(_ lhs: UnsafeRawPointer, _ rhs: UnsafeRawPointer, _ _result: UnsafeMutableRawPointer) {
            _result.assumingMemoryBound(to: MyVector2.self).initialize(to: lhs.assumingMemoryBound(to: MyVector2.self).pointee + rhs.assumingMemoryBound(to: MyVector2.self).pointee)
        }
        """
      ]
    )
  }

  @Test
  func operatorPlus_ffm_javaBindings() throws {
    try assertOutput(
      input: input,
      .ffm,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public static func + (lhs: MyVector2, rhs: MyVector2) -> MyVector2
         * }
         */
        public static MyVector2 plus(MyVector2 lhs, MyVector2 rhs, AllocatingSwiftArena swiftArena) {
            MemorySegment result$ = swiftArena.allocate(MyVector2.$LAYOUT);
            swiftjava_SwiftModule_MyVector2_plus_lhs_rhs.call(lhs.$memorySegment(), rhs.$memorySegment(), result$);
            return MyVector2.wrapMemoryAddressUnsafe(result$, swiftArena);
        }
        """
      ]
    )
  }

  @Test
  func operatorPlus_jni_swiftThunks() throws {
    try assertOutput(
      input: input,
      .jni,
      .swift,
      swiftModuleName: "FakeModule",
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyVector2__00024plus__JJ")
        public func Java_com_example_swift_MyVector2__00024plus__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, lhs: jlong, rhs: jlong) -> jlong
        """,
        """
        result$.initialize(to: lhs$.pointee + rhs$.pointee)
        let resultBits$ = Int64(Int(bitPattern: result$))
        """,
      ]
    )
  }

  @Test
  func operatorPlus_jni_javaBindings() throws {
    try assertOutput(
      input: input,
      .jni,
      .java,
      swiftModuleName: "FakeModule",
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public static func + (lhs: MyVector2, rhs: MyVector2) -> MyVector2
         * }
         */
        public static MyVector2 plus(MyVector2 lhs, MyVector2 rhs, SwiftArena swiftArena) {
            return MyVector2.wrapMemoryAddressUnsafe(MyVector2.$plus(lhs.$memoryAddress(), rhs.$memoryAddress()), swiftArena);
        }
        """
      ]
    )
  }
}
