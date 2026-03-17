//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaNet
import JavaUtilJar
import Subprocess
@_spi(Testing) import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaShared
import SwiftJavaToolLib
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

final class GenericsSubstitutionWrapJavaTests: XCTestCase {
  func testInterface() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      interface MyFunction<T, R> {
          R apply(T t);
      }

      interface MyUnaryOperator<T> extends MyFunction<T, T> {
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.MyFunction",
        "com.example.MyUnaryOperator",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaInterface("com.example.MyFunction")
        public struct MyFunction<T: AnyJavaObject, R: AnyJavaObject> {
        """,
        """
        @JavaMethod(typeErasedResult: "R!")
        public func apply(_ arg0: T?) -> R!
        """,
        """
        @JavaInterface("com.example.MyUnaryOperator", extends: MyFunction<JavaObject, JavaObject>.self)
        public struct MyUnaryOperator<T: AnyJavaObject> {
        """,
        """
        @JavaMethod(typeErasedResult: "T!")
        public func apply(_ arg0: T?) -> T!
        """,
      ]
    )
  }

  func testClass() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      abstract class ClassFunction<T, R> {
          abstract R apply(T t);
      }

      class ClassUnaryOperator<T> extends ClassFunction<T, T> {
          public T apply(T t) { return t; }
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ClassFunction",
        "com.example.ClassUnaryOperator",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaClass("com.example.ClassFunction")
        open class ClassFunction<T: AnyJavaObject, R: AnyJavaObject>: JavaObject {
        """,
        """
        @JavaMethod(typeErasedResult: "R!")
        open func apply(_ arg0: T?) -> R!
        """,
        """
        @JavaClass("com.example.ClassUnaryOperator")
        open class ClassUnaryOperator<T: AnyJavaObject>: ClassFunction<T, T> {
        """,
        """
        @JavaMethod(typeErasedResult: "T!")
        open override func apply(_ arg0: T?) -> T!
        """,
      ]
    )
  }

  func testNestedParameter() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class String {}
      interface Foo<T> {}
      interface Bar<T> {}
      interface Baz<T> {}
      interface TakeTwo<T, U> {
          void takeTwo(T t, U u);
      }

      interface MyInterface extends TakeTwo<Bar<Foo<String>>, Baz<String>> {
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.String",
        "com.example.Foo",
        "com.example.Bar",
        "com.example.Baz",
        "com.example.TakeTwo",
        "com.example.MyInterface",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaInterface("com.example.MyInterface", extends: TakeTwo<JavaObject, JavaObject>.self)
        public struct MyInterface {
        """,
        """
        @JavaMethod
        public func takeTwo(_ arg0: Bar<Foo<String>>?, _ arg1: Baz<String>?)
        """,
      ]
    )
  }

  func testDuplicatedParameterName() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class String {}
      class Integer {}

      interface Foo<T> {
        void foo(T t);
      }
      interface Bar<T> {
        void bar(T t);
      }

      interface MyInterface extends Foo<String>, Bar<Integer> {
        void foo(String t);
        void bar(Integer t);
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.String",
        "com.example.Integer",
        "com.example.Foo",
        "com.example.Bar",
        "com.example.MyInterface",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaInterface("com.example.MyInterface", extends: Foo<JavaObject>.self, Bar<JavaObject>.self)
        public struct MyInterface {
        """,
        """
        @JavaMethod
        public func foo(_ arg0: String?)
        """,
        """
        @JavaMethod
        public func bar(_ arg0: Integer?)
        """,
      ]
    )
  }
}
