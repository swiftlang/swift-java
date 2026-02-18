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

import Testing

@testable import JExtractSwiftLib

struct JNIIntConversionChecksTests {
  private let signedSource = """
    public struct MyStruct {
      public var normalInt: Int = 0

      public init(normalInt: Int) {
          self.normalInt = normalInt
      }
    }
    """
  private let unsignedSource = """
    public struct MyStruct {
      public var unsignedInt: UInt = 0

      public init(unsignedInt: UInt) {
          self.unsignedInt = unsignedInt
      }
    }
    """
  private let signedFuncSource = """
    public struct MyStruct {
      public func dummyFunc(arg: Int) -> Int {
        return arg
      }
    }
    """
  private let unsignedFuncSource = """
    public struct MyStruct {
      public func dummyFunc(arg: UInt) -> UInt {
        return arg
      }
    }
    """
  private let enumSource = """
    public enum MyEnum {
      case firstCase
      case secondCase(UInt)
    }
    """

  @Test func generatesInitWithSignedCheck() throws {
    try assertOutput(
      input: signedSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024init__J")
        public func Java_com_example_swift_MyStruct__00024init__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, normalInt: jlong) -> jlong {
          let normalInt$indirect = Int64(fromJNI: normalInt, in: environment)
          #if _pointerBitWidth(_32)
          guard normalInt$indirect >= Int32.min && normalInt$indirect <= Int32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
        """,
        """
        #endif
        let result$ = UnsafeMutablePointer<MyStruct>.allocate(capacity: 1)
        result$.initialize(to: MyStruct.init(normalInt: Int(normalInt$indirect)))
        let resultBits$ = Int64(Int(bitPattern: result$))
        return resultBits$.getJNIValue(in: environment)
        """,
      ]
    )
  }

  @Test func geberatesInitWithUnsignedCheck() throws {
    try assertOutput(
      input: unsignedSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024init__J")
        public func Java_com_example_swift_MyStruct__00024init__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, unsignedInt: jlong) -> jlong {
          let unsignedInt$indirect = UInt64(fromJNI: unsignedInt, in: environment)
          #if _pointerBitWidth(_32)
          guard unsignedInt$indirect >= UInt32.min && unsignedInt$indirect <= UInt32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
        """,
        """
        #endif
        let result$ = UnsafeMutablePointer<MyStruct>.allocate(capacity: 1)
        result$.initialize(to: MyStruct.init(unsignedInt: UInt(unsignedInt$indirect)))
        let resultBits$ = Int64(Int(bitPattern: result$))
        return resultBits$.getJNIValue(in: environment)
        """,
      ]
    )
  }

  @Test func generatesUnsignedSetterWithCheck() throws {
    try assertOutput(
      input: unsignedSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024setUnsignedInt__JJ")
        public func Java_com_example_swift_MyStruct__00024setUnsignedInt__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, self: jlong) {
          let newValue$indirect = UInt64(fromJNI: newValue, in: environment)
          #if _pointerBitWidth(_32)
            guard newValue$indirect >= UInt32.min && newValue$indirect <= UInt32.max else {
              environment.throwJavaException(javaException: .integerOverflow)
              return
        """,
        """
        #endif
        assert(self != 0, "self memory address was null")
        let selfBits$ = Int(Int64(fromJNI: self, in: environment))
        let self$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfBits$)
        guard let self$ else {
          fatalError("self memory address was null in call to \\(#function)!")
        }
        self$.pointee.unsignedInt = UInt(newValue$indirect)
        """,
      ]
    )
  }

  @Test func generatesUnsignedGetterWithoutCheck() throws {
    try assertOutput(
      input: unsignedSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024getUnsignedInt__J")
        public func Java_com_example_swift_MyStruct__00024getUnsignedInt__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jlong {
          assert(self != 0, "self memory address was null")
          let selfBits$ = Int(Int64(fromJNI: self, in: environment))
          let self$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfBits$)
          guard let self$ else {
            fatalError("self memory address was null in call to \\(#function)!")
          }
          return UInt64(self$.pointee.unsignedInt).getJNIValue(in: environment)
        """
      ]
    )
  }

  @Test func generatesSignedSetterWithCheck() throws {
    try assertOutput(
      input: signedSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024setNormalInt__JJ")
        public func Java_com_example_swift_MyStruct__00024setNormalInt__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, self: jlong) {
        let newValue$indirect = Int64(fromJNI: newValue, in: environment)
        #if _pointerBitWidth(_32)
        guard newValue$indirect >= Int32.min && newValue$indirect <= Int32.max else {
          environment.throwJavaException(javaException: .integerOverflow)
          return
        """,
        """
        #endif
        assert(self != 0, "self memory address was null")
        let selfBits$ = Int(Int64(fromJNI: self, in: environment))
        let self$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfBits$)
        guard let self$ else {
          fatalError("self memory address was null in call to \\(#function)!")
        }
        self$.pointee.normalInt = Int(newValue$indirect)
        """,
      ]
    )
  }

  @Test func generatesFuncWithSignedCheck() throws {
    try assertOutput(
      input: signedFuncSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024dummyFunc__JJ")
        public func Java_com_example_swift_MyStruct__00024dummyFunc__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg: jlong, self: jlong) -> jlong {
          let arg$indirect = Int64(fromJNI: arg, in: environment)
          #if _pointerBitWidth(_32)
          guard arg$indirect >= Int32.min && arg$indirect <= Int32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
        """,
        """
        #endif
        assert(self != 0, "self memory address was null")
        let selfBits$ = Int(Int64(fromJNI: self, in: environment))
        let self$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfBits$)
        guard let self$ else {
          fatalError("self memory address was null in call to \\(#function)!")
        }
        return Int64(self$.pointee.dummyFunc(arg: Int(arg$indirect))).getJNIValue(in: environment)
        """,
      ]
    )
  }

  @Test func generatesFuncWithUnsignedCheck() throws {
    try assertOutput(
      input: unsignedFuncSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyStruct__00024dummyFunc__JJ")
        public func Java_com_example_swift_MyStruct__00024dummyFunc__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg: jlong, self: jlong) -> jlong {
          let arg$indirect = UInt64(fromJNI: arg, in: environment)
          #if _pointerBitWidth(_32)
          guard arg$indirect >= UInt32.min && arg$indirect <= UInt32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
        """,
        """
        assert(self != 0, "self memory address was null")
        let selfBits$ = Int(Int64(fromJNI: self, in: environment))
        let self$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfBits$)
        guard let self$ else {
          fatalError("self memory address was null in call to \\(#function)!")
        }
        return UInt64(self$.pointee.dummyFunc(arg: UInt(arg$indirect))).getJNIValue(in: environment)
        """,
      ]
    )
  }

  @Test func generatesEnumCaseWithUnsignedCheck() throws {
    try assertOutput(
      input: enumSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_MyEnum__00024secondCase__J")
        public func Java_com_example_swift_MyEnum__00024secondCase__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg0: jlong) -> jlong {
          let arg0$indirect = UInt64(fromJNI: arg0, in: environment)
          #if _pointerBitWidth(_32)
          guard arg0$indirect >= UInt32.min && arg0$indirect <= UInt32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
        """,
        """
        #endif
        let result$ = UnsafeMutablePointer<MyEnum>.allocate(capacity: 1)
        result$.initialize(to: MyEnum.secondCase(UInt(arg0$indirect)))
        let resultBits$ = Int64(Int(bitPattern: result$))
        return resultBits$.getJNIValue(in: environment)
        """,
      ]
    )
  }
}
