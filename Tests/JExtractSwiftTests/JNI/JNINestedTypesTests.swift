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
struct JNINestedTypesTests {
  let source1 = """
  public class A {
    public class B {
      public func g(c: C) {}

      public struct C {
        public func h(b: B) {}
      }
    }
  }

  public func f(a: A, b: A.B, c: A.B.C) {}
  """

  @Test("Import: class and struct A.B.C (Java)")
  func nestedClassesAndStructs_java() throws {
    try assertOutput(
      input: source1,
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public final class A implements JNISwiftInstance {
          ...
          public static final class B implements JNISwiftInstance {
            ...
            public static final class C implements JNISwiftInstance {
              ...
              public void h(A.B b) {
              ...
            }
            ...
            public void g(A.B.C c) {
            ...
          }
          ...
        }
        """,
        """
        public static void f(A a, A.B b, A.B.C c) {
          ...
        }
        ...
        """
      ]
    )
  }

  @Test("Import: class and struct A.B.C (Swift)")
  func nestedClassesAndStructs_swift() throws {
    try assertOutput(
      input: source1,
      .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_A__00024destroy__J")
        func Java_com_example_swift_A__00024destroy__J(environment: UnsafeMutablePointer<CJNIEnv?>!, thisClass: jclass, selfPointer: jlong) {
          ...
        }
        """,
        """
        @_cdecl("Java_com_example_swift_A_00024B__00024destroy__J")
        func Java_com_example_swift_A_00024B__00024destroy__J(environment: UnsafeMutablePointer<CJNIEnv?>!, thisClass: jclass, selfPointer: jlong) {
          ...
        }
        """,
        """
        @_cdecl("Java_com_example_swift_A_00024B__00024destroy__J")
        func Java_com_example_swift_A_00024B__00024destroy__J(environment: UnsafeMutablePointer<CJNIEnv?>!, thisClass: jclass, selfPointer: jlong) {
          ...
        }
        """,
        """
        @_cdecl("Java_com_example_swift_A_00024B_00024C__00024h__JJ")
        func Java_com_example_swift_A_00024B_00024C__00024h__JJ(environment: UnsafeMutablePointer<CJNIEnv?>!, thisClass: jclass, b: jlong, self: jlong) {
          ...
        }
        """
      ]
    )
  }

  @Test("Import: nested in enum")
  func nestedEnums_java() throws {
    try assertOutput(
      input: """
      public enum MyError {
        case text(TextMessage)
      
        public struct TextMessage {}
      }
      
      public func f(text: MyError.TextMessage) {}
      """,
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public final class MyError implements JNISwiftInstance {
          ...
          public static final class TextMessage implements JNISwiftInstance {
          ...
          }
          ...
          public static MyError text(MyError.TextMessage arg0, SwiftArena swiftArena$) {
          ...
        }
        """,
        """
        public static void f(MyError.TextMessage text) {
          ...
        }
        """
      ]
    )
  }
}