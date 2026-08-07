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
}
