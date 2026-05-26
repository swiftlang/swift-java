//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaUtilJar
import Subprocess
@_spi(Testing) import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaShared
import SwiftJavaToolLib
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

class JavaTranslatorTests: XCTestCase {

  func translateGenericMethodParameters() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class Item<T> { 
        final T value;
        Item(T item) {
          this.value = item;
        }
      }
      class Pair<First, Second> { }

      class ExampleSimpleClass {
        <KeyType, ValueType> Pair<KeyType, ValueType> getPair(
            String name, 
            Item<KeyType> key, 
            Item<ValueType> value
        ) { return null; }
      }
      """
    )

    try withJavaTranslator(
      javaClassNames: [
        "com.example.Item",
        "com.example.Pair",
        "com.example.ExampleSimpleClass",
      ],
      classpath: [classpathURL],
    ) { translator in

    }
  }

  func testTranslateNestedParameterizedTypes() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class MyString {}
      class MyInt {}

      class Outer<T> {
        class Inner<U> {
        }

        Outer<MyString>.Inner<MyInt> foo() { return null; }
        Outer<MyInt>.Inner<T> bar() { return null; }
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.MyString",
        "com.example.MyInt",
        "com.example.Outer$Inner",
        "com.example.Outer",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        "func foo() -> Outer<MyString>.Inner<MyInt>!",
        "func bar() -> Outer<MyInt>.Inner<T>!",
      ]
    )
  }

  func testTranslateNestedParameterizedStaticTypes() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class MyOptional<Wrapped> {
        interface Case<Wrapped> {
          record None<Wrapped>() implements Case<Wrapped> {}
        }

        Case<Wrapped> getCase() { return null; }
        Case.None<Wrapped> getAsNone() { return null; }
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.MyOptional$Case",
        "com.example.MyOptional$Case$None",
        "com.example.MyOptional",
      ],
      classNameMappings: [
        "com.example.MyOptional$Case": "MyOptional.Case",
        "com.example.MyOptional$Case$None": "MyOptional.Case.None",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        "func getCase() -> MyOptional<JavaObject>.Case<Wrapped>!",
        "func getAsNone() -> MyOptional<JavaObject>.Case<JavaObject>.None<Wrapped>!",
      ]
    )
  }
}
