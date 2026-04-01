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

@Suite
struct JNISubscriptsTests {
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
    try assertOutput(
      input: noParamsSubscriptSource,
      .jni,
      .java,
      expectedChunks: [
        """
        public double getSubscript() {
          return MyStruct.$getSubscript(this.$memoryAddress());
        """,
        """
        private static native double $getSubscript(long selfPointer);
        """,
        """
        public void setSubscript(double newValue) {
          MyStruct.$setSubscript(newValue, this.$memoryAddress());
        """,
        """
        private static native void $setSubscript(double newValue, long selfPointer);
        """,
      ]
    )
  }

  @Test("Test generation of JavaClass for subscript with parameters")
  func generatesJavaClassForParameters() throws {
    try assertOutput(
      input: subscriptWithParamsSource,
      .jni,
      .java,
      expectedChunks: [
        """
        public int getSubscript(int index) {
          return MyStruct.$getSubscript(index, this.$memoryAddress());

        """,
        """
        private static native int $getSubscript(int index, long selfPointer);
        """,
        """
        public void setSubscript(int index, int newValue) {
          MyStruct.$setSubscript(index, newValue, this.$memoryAddress());
        """,
        """
         private static native void $setSubscript(int index, int newValue, long selfPointer);
        """,
      ]
    )
  }

  @Test("Test generation of Swift thunks for subscript without parameters")
  func subscriptWithoutParamsMethodSwiftThunk() throws {
    try assertOutput(
      input: noParamsSubscriptSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024getSubscript__J")
        public func Java_com_example_swift_MyStruct__00024getSubscript__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jdouble {
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(fromJNI: selfPointer, in: environment)
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          return selfPointer$.pointee[].getJNILocalRefValue(in: environment)
        """,
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024setSubscript__DJ")
        public func Java_com_example_swift_MyStruct__00024setSubscript__DJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jdouble, selfPointer: jlong) {
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(fromJNI: selfPointer, in: environment)
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          selfPointer$.pointee[] = Double(fromJNI: newValue, in: environment)
        """,
      ]
    )
  }

  @Test("Test generation of Swift thunks for subscript with parameters")
  func subscriptWithParamsMethodSwiftThunk() throws {
    try assertOutput(
      input: subscriptWithParamsSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024getSubscript__IJ")
        public func Java_com_example_swift_MyStruct__00024getSubscript__IJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, index: jint, selfPointer: jlong) -> jint {
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(fromJNI: selfPointer, in: environment)
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          return selfPointer$.pointee[Int32(fromJNI: index, in: environment)].getJNILocalRefValue(in: environment)
        """,
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024setSubscript__IIJ")
        public func Java_com_example_swift_MyStruct__00024setSubscript__IIJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, index: jint, newValue: jint, selfPointer: jlong) {
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(fromJNI: selfPointer, in: environment)
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          selfPointer$.pointee[Int32(fromJNI: index, in: environment)] = Int32(fromJNI: newValue, in: environment)
        """,
      ]
    )
  }
}
