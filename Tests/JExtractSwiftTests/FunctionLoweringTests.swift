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
import SwiftSyntax
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
      public func c_f(_ x: Int, _ y: Float, _ z$pointer: UnsafeRawPointer, _ z$count: Int) {
        f(x: x, y: y, z: UnsafeBufferPointer<Bool>(start: z$pointer.assumingMemoryBound(to: Bool.self), count: z$count))
      }
      """,
      expectedCFunction: "void c_f(ptrdiff_t x, float y, const void *z$pointer, ptrdiff_t z$count)"
    )
  }

  @Test("Lowering tuples")
  func loweringTuples() throws {
    try assertLoweredFunction("""
      func f(t: (Int, (Float, Double)), z: UnsafePointer<Int>) -> Int { }
      """,
      expectedCDecl: """
      @_cdecl("c_f")
      public func c_f(_ t_0: Int, _ t_1_0: Float, _ t_1_1: Double, _ z: UnsafePointer<Int>) -> Int {
        return f(t: (t_0, (t_1_0, t_1_1)), z: z)
      }
      """,
      expectedCFunction: "ptrdiff_t c_f(ptrdiff_t t_0, float t_1_0, double t_1_1, const ptrdiff_t *z)"
    )
  }

  @Test("Lowering String") func loweringString() throws {
    try assertLoweredFunction(
      """
      func takeString(str: String) {}
      """,
      expectedCDecl: """
      @_cdecl("c_takeString")
      public func c_takeString(_ str: UnsafePointer<Int8>) {
        takeString(str: String(cString: str))
      }
      """,
      expectedCFunction: """
      void c_takeString(const int8_t *str)
      """)
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
      expectedCFunction: "void c_shifted(double delta_0, double delta_1, const void *self, void *_result)"
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
        self.assumingMemoryBound(to: Point.self).pointee.shift(by: (delta_0, delta_1))
      }
      """,
      expectedCFunction: "void c_shift(double delta_0, double delta_1, const void *self)"
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
      public func c_randomPerson(_ seed: Double, _ _result: UnsafeMutableRawPointer) {
        _result.assumingMemoryBound(to: Person.self).initialize(to: Person.randomPerson(seed: seed))
      }
      """,
      expectedCFunction: "void c_randomPerson(double seed, void *_result)"
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
      public func c_init(_ seed: Double, _ _result: UnsafeMutableRawPointer) {
        _result.assumingMemoryBound(to: Person.self).initialize(to: Person(seed: seed))
      }
      """,
      expectedCFunction: "void c_init(double seed, void *_result)"
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
      expectedCFunction: "void c_f(const void *t)"
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
      expectedCFunction: "const void *c_f(void)"
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
      public func c_shifted(_ delta_0: Double, _ delta_1: Double, _ self: UnsafeRawPointer, _ _result: UnsafeMutableRawPointer) {
        _result.assumingMemoryBound(to: Point.self).initialize(to: self.assumingMemoryBound(to: Point.self).pointee.shifted(by: (delta_0, delta_1)))
      }
      """,
      expectedCFunction: "void c_shifted(double delta_0, double delta_1, const void *self, void *_result)"
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
      expectedCFunction: "const void *c_getPointer(void)"
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
      public func c_getTuple(_ _result_0: UnsafeMutablePointer<Int>, _ _result_1_0: UnsafeMutablePointer<Float>, _ _result_1_1: UnsafeMutableRawPointer) {
        let _result = getTuple()
        _result_0.initialize(to: _result.0)
        let _result_1 = _result.1
        _result_1_0.initialize(to: _result_1.0)
        _result_1_1.assumingMemoryBound(to: Point.self).initialize(to: _result_1.1)
      }
      """,
      expectedCFunction: "void c_getTuple(ptrdiff_t *_result_0, float *_result_1_0, void *_result_1_1)"
    )
  }

  @Test("Lowering buffer pointer returns")
  func lowerBufferPointerReturns() throws {
    try assertLoweredFunction("""
      func getBufferPointer() -> UnsafeMutableBufferPointer<Point> { }
      """,
      sourceFile: """
      struct Point { }
      """,
      expectedCDecl: """
      @_cdecl("c_getBufferPointer")
      public func c_getBufferPointer(_ _result_0: UnsafeMutablePointer<UnsafeMutableRawPointer>, _ _result_1: UnsafeMutablePointer<Int>) {
        let _result = getBufferPointer()
        _result_0.initialize(to: _result.0)
        _result_1.initialize(to: _result.1)
      }
      """,
      expectedCFunction: "void c_getBufferPointer(void **_result_0, ptrdiff_t *_result_1)"
    )
  }

  @Test("Lowering UnsafeRawBufferPointer")
  func lowerRawBufferPointer() throws {
    try assertLoweredFunction(
      """
      func swapRawBufferPointer(buffer: UnsafeRawBufferPointer) -> UnsafeMutableRawBufferPointer {}
      """,
      expectedCDecl: """
      @_cdecl("c_swapRawBufferPointer")
      public func c_swapRawBufferPointer(_ buffer$pointer: UnsafeRawPointer?, _ buffer$count: Int, _ _result$pointer: UnsafeMutablePointer<UnsafeMutableRawPointer?>, _ _result$count: UnsafeMutablePointer<Int>) {
        let _result = swapRawBufferPointer(buffer: UnsafeRawBufferPointer(start: buffer$pointer, count: buffer$count))
        _result$pointer.initialize(to: _result.baseAddress)
        _result$count.initialize(to: _result.count)
      }
      """,
      expectedCFunction: "void c_swapRawBufferPointer(const void *buffer$pointer, ptrdiff_t buffer$count, void **_result$pointer, ptrdiff_t *_result$count)"
    )
  }

  @Test("Lowering non-C-compatible closures")
  func lowerComplexClosureParameter() throws {
    try assertLoweredFunction(
      """
      func withBuffer(body: (UnsafeRawBufferPointer) -> Int) {}
      """,
      expectedCDecl: """
      @_cdecl("c_withBuffer")
      public func c_withBuffer(_ body: @convention(c) (UnsafeRawPointer?, Int) -> Int) {
        withBuffer(body: { (_0) in
          return body(_0.baseAddress, _0.count)
        })
      }
      """,
      expectedCFunction: "void c_withBuffer(ptrdiff_t (*body)(const void *, ptrdiff_t))"
    )
  }

  @Test("Lowering () -> Void type")
  func lowerSimpleClosureTypes() throws {
    try assertLoweredFunction("""
      func doSomething(body: () -> Void) { }
      """,
      expectedCDecl: """
      @_cdecl("c_doSomething")
      public func c_doSomething(_ body: @convention(c) () -> Void) {
        doSomething(body: body)
      }
      """,
      expectedCFunction: "void c_doSomething(void (*body)(void))"
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

  @Test("Lowering optional primitives")
  func lowerOptionalParameters() throws {
    try assertLoweredFunction(
      """
      func fn(a1: Optional<Int>, a2: Int?, a3: Point?, a4: (some DataProtocol)?)  
      """,
      sourceFile: """
      import Foundation
      struct Point {}
      """,
      expectedCDecl:"""
      @_cdecl("c_fn")
      public func c_fn(_ a1: UnsafePointer<Int>?, _ a2: UnsafePointer<Int>?, _ a3: UnsafeRawPointer?, _ a4: UnsafeRawPointer?) {
        fn(a1: a1?.pointee, a2: a2?.pointee, a3: a3?.assumingMemoryBound(to: Point.self).pointee, a4: a4?.assumingMemoryBound(to: Data.self).pointee)
      }
      """,
      expectedCFunction: """
      void c_fn(const ptrdiff_t *a1, const ptrdiff_t *a2, const void *a3, const void *a4)
      """)
  }

  @Test("Lowering generic parameters")
  func genericParam() throws {
    try assertLoweredFunction(
      """
      func fn<T, U: DataProtocol>(x: T, y: U?) where T: DataProtocol
      """,
      sourceFile: """
      import Foundation
      """,
      expectedCDecl: """
      @_cdecl("c_fn")
      public func c_fn(_ x: UnsafeRawPointer, _ y: UnsafeRawPointer?) {
        fn(x: x.assumingMemoryBound(to: Data.self).pointee, y: y?.assumingMemoryBound(to: Data.self).pointee)
      }
      """,
      expectedCFunction: """
      void c_fn(const void *x, const void *y)
      """
    )
  }

  @Test("Lowering read accessor")
  func lowerGlobalReadAccessor() throws {
    try assertLoweredVariableAccessor(
      DeclSyntax("""
      var value: Point = Point()
      """).cast(VariableDeclSyntax.self),
      isSet: false,
      sourceFile: """
      struct Point { }
      """,
      expectedCDecl: """
      @_cdecl("c_value")
      public func c_value(_ _result: UnsafeMutableRawPointer) {
        _result.assumingMemoryBound(to: Point.self).initialize(to: value)
      }
      """,
      expectedCFunction: "void c_value(void *_result)"
    )
  }

  @Test("Lowering set accessor")
  func lowerGlobalSetAccessor() throws {
    try assertLoweredVariableAccessor(
      DeclSyntax("""
      var value: Point { get { Point() } set {} }
      """).cast(VariableDeclSyntax.self),
      isSet: true,
      sourceFile: """
      struct Point { }
      """,
      expectedCDecl: """
      @_cdecl("c_value")
      public func c_value(_ newValue: UnsafeRawPointer) {
        value = newValue.assumingMemoryBound(to: Point.self).pointee
      }
      """,
      expectedCFunction: "void c_value(const void *newValue)"
    )
  }

  @Test("Lowering member read accessor")
  func lowerMemberReadAccessor() throws {
    try assertLoweredVariableAccessor(
      DeclSyntax("""
      var value: Int
      """).cast(VariableDeclSyntax.self),
      isSet: false,
      sourceFile: """
      struct Point { }
      """,
      enclosingType: "Point",
      expectedCDecl: """
      @_cdecl("c_value")
      public func c_value(_ self: UnsafeRawPointer) -> Int {
        return self.assumingMemoryBound(to: Point.self).pointee.value
      }
      """,
      expectedCFunction: "ptrdiff_t c_value(const void *self)"
    )
  }

  @Test("Lowering member set accessor")
  func lowerMemberSetAccessor() throws {
    try assertLoweredVariableAccessor(
      DeclSyntax("""
      var value: Point
      """).cast(VariableDeclSyntax.self),
      isSet: true,
      sourceFile: """
      class Point { }
      """,
      enclosingType: "Point",
      expectedCDecl: """
      @_cdecl("c_value")
      public func c_value(_ newValue: UnsafeRawPointer, _ self: UnsafeRawPointer) {
        self.assumingMemoryBound(to: Point.self).pointee.value = newValue.assumingMemoryBound(to: Point.self).pointee
      }
      """,
      expectedCFunction: "void c_value(const void *newValue, const void *self)"
    )
  }
}
