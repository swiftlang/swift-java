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
struct FFMOperatorsTests {
  private let source =
    """
    infix operator ==+

    public struct Number {
      public static func == (lhs: Number, rhs: Number) -> Bool {
        true
      }

      public static func ==+ (lhs: Number, rhs: Number) -> Bool {
        true
      }
    }
    """

  @Test
  func equality_swiftThunk() throws {
    try assertOutput(
      input: source,
      .ffm,
      .swift,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_Number_isEqual_lhs_rhs")
        public func swiftjava_SwiftModule_Number_isEqual_lhs_rhs(_ lhs: UnsafeRawPointer, _ rhs: UnsafeRawPointer) -> Bool {
          return (lhs.assumingMemoryBound(to: Number.self).pointee == rhs.assumingMemoryBound(to: Number.self).pointee)
        }
        """
      ]
    )
  }

  @Test
  func compoundOperator_swiftThunk() throws {
    try assertOutput(
      input: source,
      .ffm,
      .swift,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_Number_isEqualPlus_lhs_rhs")
        public func swiftjava_SwiftModule_Number_isEqualPlus_lhs_rhs(_ lhs: UnsafeRawPointer, _ rhs: UnsafeRawPointer) -> Bool {
          return (lhs.assumingMemoryBound(to: Number.self).pointee ==+ rhs.assumingMemoryBound(to: Number.self).pointee)
        }
        """
      ]
    )
  }

  @Test
  func operator_javaBinding() throws {
    try assertOutput(
      input: source,
      .ffm,
      .java,
      expectedChunks: [
        """
        private static class swiftjava_SwiftModule_Number_isEqual_lhs_rhs {
        """,
        """
        private static class swiftjava_SwiftModule_Number_isEqualPlus_lhs_rhs {
        """,
        """
        public static boolean isEqual(Number lhs, Number rhs) {
        """,
        """
        public static boolean isEqualPlus(Number lhs, Number rhs) {
        """,
      ]
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: Prefix and postfix operators

  private let prefixAndPostfixSource =
    """
    postfix operator ++

    public struct Number {
      public static prefix func - (value: Number) -> Number {
        Number()
      }

      public static postfix func ++ (value: Number) -> Number {
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
  func prefixAndPostfix_swiftThunks() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .ffm,
      .swift,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_Number_minus_value")
        public func swiftjava_SwiftModule_Number_minus_value(_ value: UnsafeRawPointer, _ _result: UnsafeMutableRawPointer) {
          _result.assumingMemoryBound(to: Number.self).initialize(to: (-value.assumingMemoryBound(to: Number.self).pointee))
        }
        """,
        """
        @_cdecl("swiftjava_SwiftModule_Number_plusPlus_value")
        public func swiftjava_SwiftModule_Number_plusPlus_value(_ value: UnsafeRawPointer, _ _result: UnsafeMutableRawPointer) {
          _result.assumingMemoryBound(to: Number.self).initialize(to: (value.assumingMemoryBound(to: Number.self).pointee++))
        }
        """,
      ]
    )
  }

  @Test
  func prefixAndPostfix_javaBindings() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static Number minus(Number value, AllocatingSwiftArena swiftArena) {
        """,
        """
        public static Number plusPlus(Number value, AllocatingSwiftArena swiftArena) {
        """,
        """
        public static Number dotDotDotPrefix(Number value, AllocatingSwiftArena swiftArena) {
        """,
        """
        public static Number dotDotDotPostfix(Number value, AllocatingSwiftArena swiftArena) {
        """,
      ]
    )
  }

  @Test
  func fileScopeOperator_swiftThunk() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .ffm,
      .swift,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_bitwiseNot_value")
        public func swiftjava_SwiftModule_bitwiseNot_value(_ value: UnsafeRawPointer, _ _result: UnsafeMutableRawPointer) {
          _result.assumingMemoryBound(to: Number.self).initialize(to: (~value.assumingMemoryBound(to: Number.self).pointee))
        }
        """
      ]
    )
  }

  @Test
  func fileScopeOperator_javaBinding() throws {
    try assertOutput(
      input: prefixAndPostfixSource,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static Number bitwiseNot(Number value, AllocatingSwiftArena swiftArena) {
        """
      ]
    )
  }
}
