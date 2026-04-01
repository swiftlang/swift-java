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
          #if _pointerBitWidth(_32)
          guard normalInt >= Int32.min && normalInt <= Int32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
          }
          #endif
          let result$ = UnsafeMutablePointer<MyStruct>.allocate(capacity: 1)
          result$.initialize(to: MyStruct.init(normalInt: Int(fromJNI: normalInt, in: environment)))
          let resultBits$ = Int64(Int(bitPattern: result$))
          return resultBits$.getJNILocalRefValue(in: environment)
        }
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
          #if _pointerBitWidth(_32)
          guard unsignedInt >= UInt32.min && unsignedInt <= UInt32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
          }
          #endif
          let result$ = UnsafeMutablePointer<MyStruct>.allocate(capacity: 1)
          result$.initialize(to: MyStruct.init(unsignedInt: UInt(fromJNI: unsignedInt, in: environment)))
          let resultBits$ = Int64(Int(bitPattern: result$))
          return resultBits$.getJNILocalRefValue(in: environment)
        }
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
        public func Java_com_example_swift_MyStruct__00024setUnsignedInt__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, selfPointer: jlong) {
          #if _pointerBitWidth(_32)
          guard newValue >= UInt32.min && newValue <= UInt32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return
          }
          #endif
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          selfPointer$.pointee.unsignedInt = UInt(fromJNI: newValue, in: environment)
        }
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
        public func Java_com_example_swift_MyStruct__00024getUnsignedInt__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, selfPointer: jlong) -> jlong {
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          return selfPointer$.pointee.unsignedInt.getJNILocalRefValue(in: environment)
        }
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
        public func Java_com_example_swift_MyStruct__00024setNormalInt__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, selfPointer: jlong) {
          #if _pointerBitWidth(_32)
          guard newValue >= Int32.min && newValue <= Int32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return
          }
          #endif
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          selfPointer$.pointee.normalInt = Int(fromJNI: newValue, in: environment)
        }
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
        public func Java_com_example_swift_MyStruct__00024dummyFunc__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg: jlong, selfPointer: jlong) -> jlong {
          #if _pointerBitWidth(_32)
          guard arg >= Int32.min && arg <= Int32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
          }
          #endif
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          return selfPointer$.pointee.dummyFunc(arg: Int(fromJNI: arg, in: environment)).getJNILocalRefValue(in: environment)
        }
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
        public func Java_com_example_swift_MyStruct__00024dummyFunc__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, arg: jlong, selfPointer: jlong) -> jlong {
          #if _pointerBitWidth(_32)
          guard arg >= UInt32.min && arg <= UInt32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
          }
          #endif
          assert(selfPointer != 0, "selfPointer memory address was null")
          let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
          let selfPointer$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfPointerBits$)
          guard let selfPointer$ else {
            fatalError("selfPointer memory address was null in call to \\(#function)!")
          }
          return selfPointer$.pointee.dummyFunc(arg: UInt(fromJNI: arg, in: environment)).getJNILocalRefValue(in: environment)
        }
        """
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
          #if _pointerBitWidth(_32)
          guard arg0 >= UInt32.min && arg0 <= UInt32.max else {
            environment.throwJavaException(javaException: .integerOverflow)
            return Int64.jniPlaceholderValue
          }
          #endif
          let result$ = UnsafeMutablePointer<MyEnum>.allocate(capacity: 1)
          result$.initialize(to: MyEnum.secondCase(UInt(fromJNI: arg0, in: environment)))
          let resultBits$ = Int64(Int(bitPattern: result$))
          return resultBits$.getJNILocalRefValue(in: environment)
        }
        """,
      ]
    )
  }
}
