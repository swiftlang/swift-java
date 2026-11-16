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
          result$.initialize(to: (((left$.pointee) + (right$.pointee)))
          let resultBits$ = Int64(Int(bitPattern: result$))
          return resultBits$.getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Prefix and postfix operators

  let prefixAndPostfixSource =
    """
    postfix operator ++
    postfix operator +++

    public struct Number {
      public static func - (left: Number, right: Number) -> Number {
        Number()
      }

      public static prefix func - (value: Number) -> Number {
        Number()
      }

      public static postfix func ++ (value: Number) -> Number {
        Number()
      }

      public static postfix func +++ (value: Number) throws -> Number {
        Number()
      }

      public static prefix func ... (value: Number) -> Number {
        Number()
      }

      public static postfix func ... (value: Number) -> Number {
        Number()
      }
    }

    public prefix func ~ (value: Number) -> Number {
      value
    }
    """

  @Test
  func prefixMinus_javaBindings() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static Number minus(Number value, SwiftArena swiftArena) {
          return Number.wrapMemoryAddressUnsafe(Number.$minus(value.$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $minus(long value);
        """,
        // The binary operator of the same name is an overload with two parameters.
        """
        public static Number minus(Number left, Number right, SwiftArena swiftArena) {
          return Number.wrapMemoryAddressUnsafe(Number.$minus(left.$memoryAddress(), right.$memoryAddress()), swiftArena);
        }
        """,
      ]
    )
  }

  @Test
  func prefixMinus_swiftThunks() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_Number__00024minus__J")
        public func Java_com_example_swift_Number__00024minus__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jlong) -> jlong {
          ...
          let result$ = UnsafeMutablePointer<Number>.allocate(capacity: 1)
          result$.initialize(to: ((-(value$.pointee))))
          ...
        }
        """
      ]
    )
  }

  @Test
  func postfixPlusPlus_javaBindings() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static Number plusPlus(Number value, SwiftArena swiftArena) {
          return Number.wrapMemoryAddressUnsafe(Number.$plusPlus(value.$memoryAddress()), swiftArena);
        }
        """,
        """
        private static native long $plusPlus(long value);
        """,
      ]
    )
  }

  @Test
  func postfixPlusPlus_swiftThunks() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_Number__00024plusPlus__J")
        public func Java_com_example_swift_Number__00024plusPlus__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jlong) -> jlong {
          ...
          let result$ = UnsafeMutablePointer<Number>.allocate(capacity: 1)
          result$.initialize(to: (((value$.pointee)++)))
          ...
        }
        """
      ]
    )
  }

  @Test
  func throwingPostfixOperator_swiftThunks() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_Number__00024plusPlusPlus__J")
        public func Java_com_example_swift_Number__00024plusPlusPlus__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jlong) -> jlong {
          ...
            result$.initialize(to: (try ((value$.pointee)+++)))
          ...
        }
        """
      ]
    )
  }

  @Test
  func prefixAndPostfixFormsOfOneOperator_javaBindings() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static Number dotDotDotPrefix(Number value, SwiftArena swiftArena) {
        """,
        """
        public static Number dotDotDotPostfix(Number value, SwiftArena swiftArena) {
        """,
      ]
    )
  }

  @Test
  func prefixAndPostfixFormsOfOneOperator_swiftThunks() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_Number__00024dotDotDotPrefix__J")
        public func Java_com_example_swift_Number__00024dotDotDotPrefix__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jlong) -> jlong {
          ...
          result$.initialize(to: ((...(value$.pointee))))
          ...
        }
        """,
        """
        @_cdecl("Java_com_example_swift_Number__00024dotDotDotPostfix__J")
        public func Java_com_example_swift_Number__00024dotDotDotPostfix__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, value: jlong) -> jlong {
          ...
          result$.initialize(to: (((value$.pointee)...)))
          ...
        }
        """,
      ]
    )
  }

  @Test
  func fileScopeOperator_isSkipped() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .jni,
      .java,
      expectedChunks: [],
      notExpectedChunks: [
        "bitwiseNot"
      ]
    )
  }
}
