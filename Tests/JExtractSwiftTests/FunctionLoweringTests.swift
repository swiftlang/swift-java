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

import JExtractSwift
import SwiftSyntax
import SwiftSyntaxBuilder
import Testing

final class FunctionLoweringTests {
  @Test("Lowering buffer pointers")
  func loweringBufferPointers() throws {
    try assertLoweredFunction("""
      func f(x: Int, y: Swift.Float, z: UnsafeBufferPointer<Bool>) { }
      """,
      expectedCDecl: """
      func f(_ x: Int, _ y: Float, _ z_pointer: UnsafeRawPointer, _ z_count: Int) -> () {
        // implementation
      }
      """
    )
  }

  @Test("Lowering tuples")
  func loweringTuples() throws {
    try assertLoweredFunction("""
      func f(t: (Int, (Float, Double)), z: UnsafePointer<Int>) { }
      """,
      expectedCDecl: """
      func f(_ t_0: Int, _ t_1_0: Float, _ t_1_1: Double, _ z_pointer: UnsafeRawPointer) -> () {
        // implementation
      }
      """
    )
  }

  @Test("Lowering methods")
  func loweringMethods() throws {
    try assertLoweredFunction("""
      func shifted(by delta: (Double, Double)) -> Point { }
      """,
      sourceFile: """
      struct Point { }
      """,
      enclosingType: "Point",
      expectedCDecl: """
      func shifted(_ self: UnsafeRawPointer, _ delta_0: Double, _ delta_1: Double, _ _result: UnsafeMutableRawPointer) -> () {
        // implementation
      }
      """
    )
  }

  @Test("Lowering metatypes", .disabled("Metatypes are not yet lowered"))
  func lowerMetatype() throws {
    try assertLoweredFunction("""
      func f(t: Int.Type) { }
      """,
      expectedCDecl: """
      func f(t: RawPointerType) -> () {
        // implementation
      }
      """
     )
  }
}

