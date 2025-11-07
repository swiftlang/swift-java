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
  @Test("Import: class and struct A.B.C")
  func nestedClassesAndStructs_java() throws {
    try assertOutput(
      input: """
      public class A {
        public class B {
          public func g(c: B) {}
      
          public struct C {
      
          }
        }
      }
      
      public func f(a: A, b: A.B, c: A.B.C) {}
      """,
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
            }
            ...
            public static void g(A.B.C c) {
            ...
          }
        ...
        }
        """,
        """
        public static void f(A a, A.B b, A.B.C c) {
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
