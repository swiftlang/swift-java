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
      public func c_f(_ x: Int, _ y: Float, _ z_pointer: UnsafeRawPointer, _ z_count: Int) {
        f(x: x, y: y, z: UnsafeBufferPointer<Bool>(start: z_pointer.assumingMemoryBound(to: Bool.self), count: z_count))
      }
      """,
      expectedCFunction: "void c_f(ptrdiff_t x, float y, void const *z_pointer, ptrdiff_t z_count)"
    )
  }

  @Test("Lowering tuples")
  func loweringTuples() throws {
    try assertLoweredFunction("""
      func f(t: (Int, (Float, Double)), z: UnsafePointer<Int>) -> Int { }
      """,
      expectedCDecl: """
      @_cdecl("c_f")
      public func c_f(_ t_0: Int, _ t_1_0: Float, _ t_1_1: Double, _ z_pointer: UnsafeRawPointer) -> Int {
        return f(t: (t_0, (t_1_0, t_1_1)), z: z_pointer.assumingMemoryBound(to: Int.self))
      }
      """,
      expectedCFunction: "ptrdiff_t c_f(ptrdiff_t t_0, float t_1_0, double t_1_1, void const *z_pointer)"
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
      public func c_shift(_ point: UnsafeMutableRawPointer, _ delta_0: Double, _ delta_1: Double) {
        shift(point: &point.assumingMemoryBound(to: Point.self).pointee, by: (delta_0, delta_1))
      }
      """,
      expectedCFunction: "void c_shift(void *point, double delta_0, double delta_1)"
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
      public func c_shifted(_ delta_0: Double, _ delta_1: Double, _ self: UnsafeRawPointer, _ _result: UnsafeMutableRawPointer) {
        _result.assumingMemoryBound(to: Point.self).initialize(to: self.assumingMemoryBound(to: Point.self).pointee.shifted(by: (delta_0, delta_1)))
      }
      """,
      expectedCFunction: "void c_shifted(double delta_0, double delta_1, void const *self, void *_result)"
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
      public func c_shift(_ delta_0: Double, _ delta_1: Double, _ self: UnsafeMutableRawPointer) {
        self.assumingMemoryBound(to: Point.self).pointee.shift(by: (delta_0, delta_1))
      }
      """,
      expectedCFunction: "void c_shift(double delta_0, double delta_1, void *self)"
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
      public func c_shift(_ delta_0: Double, _ delta_1: Double, _ self: UnsafeRawPointer) {
        unsafeBitCast(self, to: Point.self).shift(by: (delta_0, delta_1))
      }
      """,
      expectedCFunction: "void c_shift(double delta_0, double delta_1, void const *self)"
    )
  }

  @Test("Lowering static methods")
  func loweringStaticMethods() throws {
    try assertLoweredFunction("""
      static func scaledUnit(by value: Double) -> Point { }
      """,
      sourceFile: """
      struct Point { }
      """,
      enclosingType: "Point",
      expectedCDecl: """
      @_cdecl("c_scaledUnit")
      public func c_scaledUnit(_ value: Double, _ _result: UnsafeMutableRawPointer) {
        _result.assumingMemoryBound(to: Point.self).initialize(to: Point.scaledUnit(by: value))
      }
      """,
      expectedCFunction: "void c_scaledUnit(double value, void *_result)"
    )

    try assertLoweredFunction("""
      static func randomPerson(seed: Double) -> Person { }
      """,
      sourceFile: """
      class Person { }
      """,
      enclosingType: "Person",
      expectedCDecl: """
      @_cdecl("c_randomPerson")
      public func c_randomPerson(_ seed: Double) -> UnsafeRawPointer {
        return unsafeBitCast(Person.randomPerson(seed: seed), to: UnsafeRawPointer.self)
      }
      """,
      expectedCFunction: "void const *c_randomPerson(double seed)"
    )
  }

  @Test("Lowering initializers")
  func loweringInitializers() throws {
    try assertLoweredFunction("""
      init(scaledBy value: Double) { }
      """,
      sourceFile: """
      struct Point { }
      """,
      enclosingType: "Point",
      expectedCDecl: """
      @_cdecl("c_init")
      public func c_init(_ value: Double, _ _result: UnsafeMutableRawPointer) {
        _result.assumingMemoryBound(to: Point.self).initialize(to: Point(scaledBy: value))
      }
      """,
      expectedCFunction: "void c_init(double value, void *_result)"
    )

    try assertLoweredFunction("""
      init(seed: Double) { }
      """,
      sourceFile: """
      class Person { }
      """,
      enclosingType: "Person",
      expectedCDecl: """
      @_cdecl("c_init")
      public func c_init(_ seed: Double) -> UnsafeRawPointer {
        return unsafeBitCast(Person(seed: seed), to: UnsafeRawPointer.self)
      }
      """,
      expectedCFunction: "void const *c_init(double seed)"
    )
  }

  @Test("Lowering metatypes")
  func lowerMetatype() throws {
    try assertLoweredFunction("""
      func f(t: Int.Type) { }
      """,
      expectedCDecl: """
      @_cdecl("c_f")
      public func c_f(_ t: UnsafeRawPointer) {
        f(t: unsafeBitCast(t, to: Int.self))
      }
      """,
      expectedCFunction: "void c_f(void const *t)"
    )

    try assertLoweredFunction("""
      func f() -> Int.Type { }
      """,
      expectedCDecl: """
      @_cdecl("c_f")
      public func c_f() -> UnsafeRawPointer {
        return unsafeBitCast(f(), to: UnsafeRawPointer.self)
      }
      """,
      expectedCFunction: "void const *c_f(void)"
    )
  }

  @Test("Lowering class returns")
  func lowerClassReturns() throws {
    try assertLoweredFunction("""
      func shifted(by delta: (Double, Double)) -> Point { }
      """,
      sourceFile: """
      class Point { }
      """,
      enclosingType: "Point",
      expectedCDecl: """
      @_cdecl("c_shifted")
      public func c_shifted(_ delta_0: Double, _ delta_1: Double, _ self: UnsafeRawPointer) -> UnsafeRawPointer {
        return unsafeBitCast(unsafeBitCast(self, to: Point.self).shifted(by: (delta_0, delta_1)), to: UnsafeRawPointer.self)
      }
      """,
      expectedCFunction: "void const *c_shifted(double delta_0, double delta_1, void const *self)"
    )
  }

  @Test("Lowering pointer returns")
  func lowerPointerReturns() throws {
    try assertLoweredFunction("""
      func getPointer() -> UnsafePointer<Point> { }
      """,
      sourceFile: """
      struct Point { }
      """,
      expectedCDecl: """
      @_cdecl("c_getPointer")
      public func c_getPointer() -> UnsafeRawPointer {
        return UnsafeRawPointer(getPointer())
      }
      """,
      expectedCFunction: "void const *c_getPointer(void)"
    )
  }

  @Test("Lowering tuple returns")
  func lowerTupleReturns() throws {
    try assertLoweredFunction("""
      func getTuple() -> (Int, (Float, Point)) { }
      """,
      sourceFile: """
      struct Point { }
      """,
      expectedCDecl: """
      @_cdecl("c_getTuple")
      public func c_getTuple(_ _result_0: UnsafeMutableRawPointer, _ _result_1_0: UnsafeMutableRawPointer, _ _result_1_1: UnsafeMutableRawPointer) {
        let __swift_result = getTuple()
        _result_0 = __swift_result_0
        _result_1_0 = __swift_result_1_0
        _result_1_1.assumingMemoryBound(to: Point.self).initialize(to: __swift_result_1_1)
      }
      """,
      expectedCFunction: "void c_getTuple(void *_result_0, void *_result_1_0, void *_result_1_1)"
    )
  }

  @Test("Lowering buffer pointer returns", .disabled("Doesn't turn into the indirect returns"))
  func lowerBufferPointerReturns() throws {
    try assertLoweredFunction("""
      func getBufferPointer() -> UnsafeMutableBufferPointer<Point> { }
      """,
      sourceFile: """
      struct Point { }
      """,
      expectedCDecl: """
      @_cdecl("c_getBufferPointer")
      public func c_getBufferPointer(_result_pointer: UnsafeMutableRawPointer, _result_count: UnsafeMutableRawPointer) {
        return UnsafeRawPointer(getPointer())
      }
      """,
      expectedCFunction: "c_getBufferPointer(void* _result_pointer, void* _result_count)"
    )
  }

  @Test("Lowering C function types")
  func lowerFunctionTypes() throws {
    // FIXME: C pretty printing isn't handling parameters of function pointer
    // type yet.
    try assertLoweredFunction("""
      func doSomething(body: @convention(c) (Int32) -> Double) { }
      """,
      expectedCDecl: """
      @_cdecl("c_doSomething")
      public func c_doSomething(_ body: @convention(c) (Int32) -> Double) {
        doSomething(body: body)
      }
      """,
      expectedCFunction: "void c_doSomething(double (*body)(int32_t))"
    )
  }
}
