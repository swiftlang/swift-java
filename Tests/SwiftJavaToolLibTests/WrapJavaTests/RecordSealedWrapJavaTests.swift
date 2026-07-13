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

import Foundation
import JavaNet
import JavaUtilJar
import Subprocess
@_spi(Testing) import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaShared
import SwiftJavaToolLib
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

final class RecordSealedWrapJavaTests: XCTestCase {

  func test_wrapJava_javaRecord_isMarkedInDocs() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public record Point(int x, int y) {}
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Point"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        /// Java record: `com.example.Point`
        @JavaRecord("com.example.Point")
        open class Point: JavaObject {
          @JavaMethod
          @_nonoverride public convenience init(_ x: Int32, _ y: Int32, environment: JNIEnvironment? = nil)
        """
      ]
    )
  }

  func test_wrapJava_javaSealed_isMarkedInDocs_withPermits() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public sealed class Shape permits Circle, Square {}
      final class Circle extends Shape {}
      final class Square extends Shape {}
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Shape",
        "com.example.Circle",
        "com.example.Square",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        /// Java `sealed class`, permits: ``Circle`` (`com.example.Circle`), ``Square`` (`com.example.Square`)
        @JavaClass(.sealed, "com.example.Shape", permits: Circle.self, Square.self)
        open class Shape:
        """
      ]
    )
  }

  func test_wrapJava_javaSealedInterface_isMarkedInDocs_withPermits() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public sealed interface Op permits Add, Mul {}
      final class Add implements Op {}
      final class Mul implements Op {}
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Op",
        "com.example.Add",
        "com.example.Mul",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        /// Java `sealed interface`, permits: ``Add`` (`com.example.Add`), ``Mul`` (`com.example.Mul`)
        @JavaInterface(.sealed, "com.example.Op", permits: Add.self, Mul.self)
        public struct Op {
        """
      ]
    )
  }
}
