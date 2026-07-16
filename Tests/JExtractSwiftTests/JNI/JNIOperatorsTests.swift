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
struct JNIOperatorsTests {
  let source =
    """
    infix operator ==+
    infix operator >=>=++
    infix operator <<>>==+

    public struct Number {
      public static func + (left: Number, right: Number) -> Number {
        Number()
      }

      public static func ==+ (left: Number, right: Number) -> Number {
        Number()
      }

      public static func >=>=++ (left: Number, right: Number) -> Number {
        Number()
      }

      public static func <<>>==+ (left: Number, right: Number) -> Number {
        Number()
      }
    }
    """

  @Test
  func plus_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public static func + (left: Number, right: Number) -> Number
         * }
         */
        public static Number plus(Number left, Number right, SwiftArena swiftArena) {
          return Number.wrapMemoryAddressUnsafe(Number.$plus(left.$memoryAddress(), right.$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $plus(long left, long right);
        """,
      ]
    )
  }

  @Test
  func isEqualPlus_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static Number isEqualPlus(Number left, Number right, SwiftArena swiftArena) {
          return Number.wrapMemoryAddressUnsafe(Number.$isEqualPlus(left.$memoryAddress(), right.$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $isEqualPlus(long left, long right);
        """,
      ]
    )
  }

  @Test
  func repeatedGreaterThanOrEqual_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static Number greaterThanOrEqualGreaterThanOrEqualPlusPlus(Number left, Number right, SwiftArena swiftArena) {
          return Number.wrapMemoryAddressUnsafe(Number.$greaterThanOrEqualGreaterThanOrEqualPlusPlus(left.$memoryAddress(), right.$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $greaterThanOrEqualGreaterThanOrEqualPlusPlus(long left, long right);
        """,
      ]
    )
  }

  @Test
  func mixedTwoCharacterTokens_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static Number shiftedLeftShiftedRightIsEqualPlus(Number left, Number right, SwiftArena swiftArena) {
          return Number.wrapMemoryAddressUnsafe(Number.$shiftedLeftShiftedRightIsEqualPlus(left.$memoryAddress(), right.$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $shiftedLeftShiftedRightIsEqualPlus(long left, long right);
        """,
      ]
    )
  }

  @Test
  func plus_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_Number__00024plus__JJ")
        public func Java_com_example_swift_Number__00024plus__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, left: jlong, right: jlong) -> jlong {
          ...
          let result$ = UnsafeMutablePointer<Number>.allocate(capacity: 1)
          result$.initialize(to: ( ((left$.pointee) + (right$.pointee)))
          let resultBits$ = Int64(Int(bitPattern: result$))
          return resultBits$.getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }
}
