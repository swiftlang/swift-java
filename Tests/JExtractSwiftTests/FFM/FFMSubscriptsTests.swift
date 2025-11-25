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
import Testing

import JExtractSwiftLib
import Testing

@Suite
struct FFMSubscriptsTests {
  private let noParamsSubscriptSource = """
  public struct MyStruct {
    private var testVariable: Double = 0

    public subscript() -> Double {
      get { return testVariable }
      set { testVariable = newValue }
    }
  }
  """

  private let subscriptWithParamsSource = """
  public struct MyStruct {
    private var testVariable: [Int32] = []

    public subscript(index: Int32) -> Int32 {
      get { return testVariable[Int(index)] }
      set { testVariable[Int(index)] = newValue }
    }
  }
  """

  @Test("Test generation of JavaClass for subscript with no parameters")
  func generatesJavaClassForNoParams() throws {
    try assertOutput(input: noParamsSubscriptSource, .ffm, .java, expectedChunks: [
      """
      private static class swiftjava_SwiftModule_MyStruct_subscript$get {
        private static final FunctionDescriptor DESC = FunctionDescriptor.of(
          /* -> */SwiftValueLayout.SWIFT_DOUBLE,
          /* self: */SwiftValueLayout.SWIFT_POINTER
        );
      """,
      """
      private static final MemorySegment ADDR =
        SwiftModule.findOrThrow("swiftjava_SwiftModule_MyStruct_subscript$get");
      """,
      """
      private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
      public static double call(java.lang.foreign.MemorySegment self) {
        try {
          if (CallTraces.TRACE_DOWNCALLS) {
            CallTraces.traceDowncall(self);
          }
          return (double) HANDLE.invokeExact(self);
        } catch (Throwable ex$) {
          throw new AssertionError("should not reach here", ex$);
        }
      }
      """,
      """
      public double getSubscript() {
        $ensureAlive();
        return swiftjava_SwiftModule_MyStruct_subscript$get.call(this.$memorySegment());
      """,
    ])
    try assertOutput(input: noParamsSubscriptSource, .ffm, .java, expectedChunks: [
      """
      private static class swiftjava_SwiftModule_MyStruct_subscript$set {
        private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
          /* newValue: */SwiftValueLayout.SWIFT_DOUBLE,
          /* self: */SwiftValueLayout.SWIFT_POINTER
        );
        private static final MemorySegment ADDR =
          SwiftModule.findOrThrow("swiftjava_SwiftModule_MyStruct_subscript$set");
        private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
        public static void call(double newValue, java.lang.foreign.MemorySegment self) {
          try {
            if (CallTraces.TRACE_DOWNCALLS) {
              CallTraces.traceDowncall(newValue, self);
            }
            HANDLE.invokeExact(newValue, self);
          } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
          }
        }
      """,
      """
      public void setSubscript(double newValue) {
        $ensureAlive();
        swiftjava_SwiftModule_MyStruct_subscript$set.call(newValue, this.$memorySegment());
      """
    ])
  }

  @Test("Test generation of JavaClass for subscript with parameters")
  func generatesJavaClassForParameters() throws {
    try assertOutput(input: subscriptWithParamsSource, .ffm, .java, expectedChunks: [
      """
      private static class swiftjava_SwiftModule_MyStruct_subscript$get {
        private static final FunctionDescriptor DESC = FunctionDescriptor.of(
          /* -> */SwiftValueLayout.SWIFT_INT32,
          /* index: */SwiftValueLayout.SWIFT_INT32,
          /* self: */SwiftValueLayout.SWIFT_POINTER
        );
        private static final MemorySegment ADDR =
          SwiftModule.findOrThrow("swiftjava_SwiftModule_MyStruct_subscript$get");
        private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
        public static int call(int index, java.lang.foreign.MemorySegment self) {
          try {
            if (CallTraces.TRACE_DOWNCALLS) {
              CallTraces.traceDowncall(index, self);
            }
            return (int) HANDLE.invokeExact(index, self);
          } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
          }
        }
      """,
      """
      public int getSubscript(int index) {
        $ensureAlive();
        return swiftjava_SwiftModule_MyStruct_subscript$get.call(index, this.$memorySegment());
      """,
    ])
    try assertOutput(input: subscriptWithParamsSource, .ffm, .java, expectedChunks: [
      """
      private static class swiftjava_SwiftModule_MyStruct_subscript$set {
        private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
          /* index: */SwiftValueLayout.SWIFT_INT32,
          /* newValue: */SwiftValueLayout.SWIFT_INT32,
          /* self: */SwiftValueLayout.SWIFT_POINTER
        );
        private static final MemorySegment ADDR =
          SwiftModule.findOrThrow("swiftjava_SwiftModule_MyStruct_subscript$set");
        private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
        public static void call(int index, int newValue, java.lang.foreign.MemorySegment self) {
          try {
            if (CallTraces.TRACE_DOWNCALLS) {
              CallTraces.traceDowncall(index, newValue, self);
            }
            HANDLE.invokeExact(index, newValue, self);
          } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
          }
        }
      """,
      """
      public void setSubscript(int index, int newValue) {
        $ensureAlive();
        swiftjava_SwiftModule_MyStruct_subscript$set.call(index, newValue, this.$memorySegment());
      """,
    ])
  }

  @Test("Test generation of Swift thunks for subscript without parameters")
  func subscriptWithoutParamsMethodSwiftThunk() throws {
    try assertOutput(
      input: noParamsSubscriptSource,
      .ffm,
      .swift,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_MyStruct_subscript$get")
        public func swiftjava_SwiftModule_MyStruct_subscript$get(_ self: UnsafeRawPointer) -> Double {
          return self.assumingMemoryBound(to: MyStruct.self).pointee[]
        }
        """,
        """
        @_cdecl("swiftjava_SwiftModule_MyStruct_subscript$set")
        public func swiftjava_SwiftModule_MyStruct_subscript$set(_ newValue: Double, _ self: UnsafeMutableRawPointer) {
          self.assumingMemoryBound(to: MyStruct.self).pointee[] = newValue
        }
        """
      ]
    )
  }

  @Test("Test generation of Swift thunks for subscript with parameters")
  func subscriptWithParamsMethodSwiftThunk() throws {
    try assertOutput(
      input: subscriptWithParamsSource,
      .ffm,
      .swift,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_MyStruct_subscript$get")
        public func swiftjava_SwiftModule_MyStruct_subscript$get(_ index: Int32, _ self: UnsafeRawPointer) -> Int32 {
          return self.assumingMemoryBound(to: MyStruct.self).pointee[index]
        }
        """,
        """
        @_cdecl("swiftjava_SwiftModule_MyStruct_subscript$set")
        public func swiftjava_SwiftModule_MyStruct_subscript$set(_ index: Int32, _ newValue: Int32, _ self: UnsafeMutableRawPointer) {
          self.assumingMemoryBound(to: MyStruct.self).pointee[index] = newValue
        }
        """
      ]
    )
  }
}
