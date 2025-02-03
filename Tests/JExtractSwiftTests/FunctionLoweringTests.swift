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

@Suite("Swift function lowering tests")
final class FunctionLoweringTests {
  @Test("Lowering buffer pointers")
  func loweringBufferPointers() throws {
    try assertLoweredFunction("""
      func f(x: Int, y: Swift.Float, z: UnsafeBufferPointer<Bool>) { }
      """,
      expectedCDecl: """
      @_cdecl("c_f")
      func c_f(_ x: Int, _ y: Float, _ z_pointer: UnsafeRawPointer, _ z_count: Int) {
        f(x: x, y: y, z: UnsafeBufferPointer<Bool>(start: z_pointer.assumingMemoryBound(to: Bool.self), count: z_count))
      }
      """,
      expectedCFunction: "void c_f(ptrdiff_t x, float y, void const* z_pointer, ptrdiff_t z_count)"
    )
  }

  @Test("Lowering tuples")
  func loweringTuples() throws {
    try assertLoweredFunction("""
      func f(t: (Int, (Float, Double)), z: UnsafePointer<Int>) -> Int { }
      """,
      expectedCDecl: """
      @_cdecl("c_f")
      func c_f(_ t_0: Int, _ t_1_0: Float, _ t_1_1: Double, _ z_pointer: UnsafeRawPointer) -> Int {
        return f(t: (t_0, (t_1_0, t_1_1)), z: z_pointer.assumingMemoryBound(to: Int.self))
      }
      """,
      expectedCFunction: "ptrdiff_t c_f(ptrdiff_t t_0, float t_1_0, double t_1_1, void const* z_pointer)"
    )
  }

  @Test("Lowering functions involving inout")
  func loweringInoutParameters() throws {
    try assertLoweredFunction("""
      func shift(point: inout Point, by delta: (Double, Double)) { }
      """,
      sourceFile: """
      struct Point { }
      """,
      expectedCDecl: """
      @_cdecl("c_shift")
      func c_shift(_ point: UnsafeMutableRawPointer, _ delta_0: Double, _ delta_1: Double) {
        shift(point: &point.assumingMemoryBound(to: Point.self).pointee, by: (delta_0, delta_1))
      }
      """,
      expectedCFunction: "void c_shift(void* point, double delta_0, double delta_1)"
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
      @_cdecl("c_shifted")
      func c_shifted(_ delta_0: Double, _ delta_1: Double, _ _result: UnsafeMutableRawPointer, _ self: UnsafeRawPointer) {
        _result.assumingMemoryBound(to: Point.self).pointee = self.assumingMemoryBound(to: Point.self).pointee.shifted(by: (delta_0, delta_1))
      }
      """,
      expectedCFunction: "void c_shifted(double delta_0, double delta_1, void* _result, void const* self)"
    )
  }

  @Test("Lowering mutating methods")
  func loweringMutatingMethods() throws {
    try assertLoweredFunction("""
      mutating func shift(by delta: (Double, Double)) { }
      """,
      sourceFile: """
      struct Point { }
      """,
      enclosingType: "Point",
      expectedCDecl: """
      @_cdecl("c_shift")
      func c_shift(_ delta_0: Double, _ delta_1: Double, _ self: UnsafeMutableRawPointer) {
        self.assumingMemoryBound(to: Point.self).pointee.shift(by: (delta_0, delta_1))
      }
      """,
      expectedCFunction: "void c_shift(double delta_0, double delta_1, void* self)"
    )
  }

  @Test("Lowering instance methods of classes")
  func loweringInstanceMethodsOfClass() throws {
    try assertLoweredFunction("""
      func shift(by delta: (Double, Double)) { }
      """,
      sourceFile: """
      class Point { }
      """,
      enclosingType: "Point",
      expectedCDecl: """
      @_cdecl("c_shift")
      func c_shift(_ delta_0: Double, _ delta_1: Double, _ self: UnsafeRawPointer) {
        unsafeBitCast(self, to: Point.self).shift(by: (delta_0, delta_1))
      }
      """,
      expectedCFunction: "void c_shift(double delta_0, double delta_1, void const* self)"
    )
  }

  @Test("Lowering metatypes")
  func lowerMetatype() throws {
    try assertLoweredFunction("""
      func f(t: Int.Type) { }
      """,
      expectedCDecl: """
      @_cdecl("c_f")
      func c_f(_ t: UnsafeRawPointer) {
        f(t: unsafeBitCast(t, to: Int.self))
      }
      """,
      expectedCFunction: "void c_f(void const* t)"
     )
  }
}

