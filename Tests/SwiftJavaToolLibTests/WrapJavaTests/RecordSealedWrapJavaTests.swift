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

  func test_wrapJava_javaSealed_isMarkedInDocs() async throws {
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
        /// Java `sealed class`, permits:
        /// - ``Circle`` (`com.example.Circle`)
        /// - ``Square`` (`com.example.Square`)
        @JavaClass(.sealed, "com.example.Shape")
        open class Shape:
        """
      ]
    )
  }

  func test_wrapJava_javaSealedInterface_isTranslatedAsSwiftEnum() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public sealed interface Op permits Add, Mul {
        Op combine(Op other);
      }
      final class Add implements Op {
        @Override public Op combine(Op other) { return this; }
      }
      final class Mul implements Op {
        @Override public Op combine(Op other) { return this; }
      }
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
        // Sealed interface becomes a Swift enum. The permitted subclasses
        // are modelled as typed cases plus an `unknown` catch-all for any
        // Java subclass whose Swift wrapper hasn't been generated. The
        // interface's own methods are emitted on the enum itself,
        // so callers can dispatch without pattern-matching first. The
        // macro-generated body invokes `dynamicJavaMethodCall` on the
        // enum (which conforms to `AnyJavaObject` via the extension
        // macro) and wraps the result back into the enum via
        // `init(javaHolder:)`.
        """
        /// Java `sealed interface`, permits:
        /// - ``Add`` (`com.example.Add`)
        /// - ``Mul`` (`com.example.Mul`)
        @JavaInterface(.sealed, "com.example.Op")
        public enum Op {
          case add(Add)

          case mul(Mul)

          case unknown(JavaObject)

          public var javaHolder: JavaObjectHolder {
            switch self {
            case .add(let v):
              return v.javaHolder
            case .mul(let v):
              return v.javaHolder
            case .unknown(let v):
              return v.javaHolder
            }
          }

          public init(javaHolder: JavaObjectHolder) {
            let raw = JavaObject(javaHolder: javaHolder)
            if let v = raw.as(Add.self) {
              self = .add(v)
              return
            }
            if let v = raw.as(Mul.self) {
              self = .mul(v)
              return
            }
            self = .unknown(raw)
          }

          /// Java method `combine`.
          ///
          /// ### Java method signature
          /// ```java
          /// public abstract com.example.Op com.example.Op.combine(com.example.Op)
          /// ```
          @JavaMethod
          public func combine(_ arg0: Op?) -> Op!
        }
        """,
        // The Java `Op combine(Op)` method is inherited by each permitted
        // subclass; wrap-java re-emits it on the concrete `Add` / `Mul`
        // wrappers too, so callers holding a concrete case can call
        // `.combine(...)` without pattern matching.
        """
        @JavaClass("com.example.Add", implements: Op.self)
        open class Add: JavaObject {
          /// Java method `combine`.
          ///
          /// ### Java method signature
          /// ```java
          /// public com.example.Op com.example.Add.combine(com.example.Op)
          /// ```
          @JavaMethod
          open func combine(_ arg0: Op?) -> Op!
        }
        """,
        """
        @JavaClass("com.example.Mul", implements: Op.self)
        open class Mul: JavaObject {
          /// Java method `combine`.
          ///
          /// ### Java method signature
          /// ```java
          /// public com.example.Op com.example.Mul.combine(com.example.Op)
          /// ```
          @JavaMethod
          open func combine(_ arg0: Op?) -> Op!
        }
        """,
      ]
    )
  }
}
