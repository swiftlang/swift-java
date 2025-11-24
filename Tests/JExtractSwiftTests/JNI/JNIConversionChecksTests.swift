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

@testable import JExtractSwiftLib
import Testing

struct JNIConversionChecksTests {
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

  @Test func generatesUnsignedSetterWithCheck() throws {
    try assertOutput(input: unsignedSource, .jni, .swift, expectedChunks: [
      """
      @_cdecl("Java_com_example_swift_MyStruct__00024setUnsignedInt__JJ")
      func Java_com_example_swift_MyStruct__00024setUnsignedInt__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, self: jlong) {
        let indirect_newValue = UInt64(fromJNI: newValue, in: environment)
        #if _pointerBitWidth(_32)
          guard indirect_newValue >= UInt32.min && indirect_newValue <= UInt32.max else {
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
      self$.pointee.unsignedInt = UInt(indirect_newValue)
      """
      ])
  }

  @Test func generatesUnsignedGetterWithoutCheck() throws {
    try assertOutput(input: unsignedSource, .jni, .swift, expectedChunks: [
      """
      @_cdecl("Java_com_example_swift_MyStruct__00024getUnsignedInt__J")
      func Java_com_example_swift_MyStruct__00024getUnsignedInt__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jlong {
        assert(self != 0, "self memory address was null")
        let selfBits$ = Int(Int64(fromJNI: self, in: environment))
        let self$ = UnsafeMutablePointer<MyStruct>(bitPattern: selfBits$)
        guard let self$ else {
          fatalError("self memory address was null in call to \\(#function)!")
        }
        return self$.pointee.unsignedInt.getJNIValue(in: environment)
      """
      ])
  }

  @Test func generatesSignedSetterWithCheck() throws {
    try assertOutput(input: signedSource, .jni, .swift, expectedChunks: [
      """
      @_cdecl("Java_com_example_swift_MyStruct__00024setNormalInt__JJ")
      func Java_com_example_swift_MyStruct__00024setNormalInt__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, newValue: jlong, self: jlong) {
      let indirect_newValue = Int64(fromJNI: newValue, in: environment)
      #if _pointerBitWidth(_32)
      guard indirect_newValue >= Int32.min && indirect_newValue <= Int32.max else {
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
      self$.pointee.normalInt = Int(indirect_newValue)
      """
      ])
  }
}
