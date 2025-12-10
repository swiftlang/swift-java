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

}
