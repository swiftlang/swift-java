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

@_spi(Testing) import SwiftJava
import SwiftJavaToolLib
import JavaUtilJar
import SwiftJavaShared
import JavaNet
import SwiftJavaConfigurationShared
import Subprocess
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

final class BasicWrapJavaTests: XCTestCase {

  func testWrapJavaFromCompiledJavaSource() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class ExampleSimpleClass {}
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ExampleSimpleClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import CSwiftJavaJNI
        import SwiftJava
        """,
        """
        @JavaClass("com.example.ExampleSimpleClass")
        open class ExampleSimpleClass: JavaObject {
        """
      ]
    )
  }

  func test_wrapJava_doNotDupeImportNestedClassesFromSuperclassAutomatically() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class SuperClass {
        class SuperNested {} 
      }

      class ExampleSimpleClass {
        class SimpleNested {} 
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.SuperClass",
        "com.example.SuperClass$SuperNested",
        "com.example.ExampleSimpleClass",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaClass("com.example.SuperClass")
        open class SuperClass: JavaObject {
        """,
        // FIXME: the mapping configuration could be used to nest this properly but today we don't automatically?
        """
        @JavaClass("com.example.SuperClass$SuperNested")
        open class SuperNested: JavaObject {
        """,
        """
        @JavaClass("com.example.SuperClass")
        open class SuperClass: JavaObject {
        """,
      ]
    )
  }

  // Test that static fields from superclasses are not duplicated in generated code.
  // This prevents duplicate serialVersionUID declarations when both a class and its
  // superclass declare the field. The subclass field "hides" the superclass field,
  // similar to how static methods work in Java.
  func test_wrapJava_noDuplicateStaticFieldsFromSuperclass() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class SuperClass {
        public static final long serialVersionUID = 1L;
      }

      class SubClass extends SuperClass {
        public static final long serialVersionUID = 2L;
      }
      """)

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.SuperClass",
        "com.example.SubClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        // SuperClass should have its static field
        """
        extension JavaClass<SuperClass> {
        @JavaStaticField(isFinal: true)
        public var serialVersionUID: Int64
        """,
        // SubClass should only have its own static field, not the superclass one
        """
        extension JavaClass<SubClass> {
        @JavaStaticField(isFinal: true)
        public var serialVersionUID: Int64
        """,
      ]
    )
  }
}
