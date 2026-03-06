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

import Foundation
import JavaNet
import JavaUtilJar
import Subprocess
@_spi(Testing) import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaShared
import SwiftJavaToolLib
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

final class AnnotationsWrapJavaTests: XCTestCase {

  // ==== ------------------------------------------------
  // MARK: @Deprecated

  func testWrapJava_deprecatedMethod() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class DeprecatedExample {
          @Deprecated
          public void oldMethod() {}
          public void newMethod() {}
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.DeprecatedExample"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @available(*, deprecated)
        @JavaMethod
        open func oldMethod()
        """,
        """
        @JavaMethod
        open func newMethod()
        """,
      ]
    )
  }

  func testWrapJava_deprecatedClass() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      @Deprecated
      class OldClass {
          public void doSomething() {}
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.OldClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @available(*, deprecated)
        @JavaClass("com.example.OldClass")
        open class OldClass: JavaObject {
        """
      ]
    )
  }

  func testWrapJava_deprecatedField() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class FieldExample {
          @Deprecated
          public static int OLD_VALUE = 42;
          public static int NEW_VALUE = 99;
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.FieldExample"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @available(*, deprecated)
        @JavaStaticField(isFinal: false)
        public var OLD_VALUE: Int32
        """,
        """
        @JavaStaticField(isFinal: false)
        public var NEW_VALUE: Int32
        """,
      ]
    )
  }

  func testWrapJava_deprecatedConstructor() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class ConstructorExample {
          @Deprecated
          public ConstructorExample() {}
          public ConstructorExample(int value) {}
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ConstructorExample"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @available(*, deprecated)
        @JavaMethod
        @_nonoverride public convenience init(environment: JNIEnvironment? = nil)
        """
      ]
    )
  }

  // ==== ------------------------------------------------
  // MARK: @RequiresApi

  func testWrapJava_requiresApiMethod() async throws {
    let classpathURL = try await compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java":
        """
      package androidx.annotation;
      import java.lang.annotation.*;
      @Retention(RetentionPolicy.RUNTIME)
      @Target({ElementType.TYPE, ElementType.METHOD, ElementType.CONSTRUCTOR, ElementType.FIELD})
      public @interface RequiresApi {
          int api() default 1;
          int value() default 1;
      }
      """,
      "com/example/ApiLevelExample.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      class ApiLevelExample {
          @RequiresApi(api = 30)
          public void api30Method() {}
          public void anyApiMethod() {}
      }
      """,
    ])

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ApiLevelExample"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 30 /* Android 11 */, *)
        #endif
        @JavaMethod
        open func api30Method()
        """,
        """
        @JavaMethod
        open func anyApiMethod()
        """,
      ]
    )
  }

  // ==== ------------------------------------------------
  // MARK: @Deprecated + @RequiresApi

  func testWrapJava_deprecatedAndRequiresApi() async throws {
    let classpathURL = try await compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java":
        """
      package androidx.annotation;
      import java.lang.annotation.*;
      @Retention(RetentionPolicy.RUNTIME)
      @Target({ElementType.TYPE, ElementType.METHOD, ElementType.CONSTRUCTOR, ElementType.FIELD})
      public @interface RequiresApi {
          int api() default 1;
          int value() default 1;
      }
      """,
      "com/example/BothAnnotations.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      class BothAnnotations {
          @Deprecated
          @RequiresApi(api = 28)
          public void oldApi28Method() {}
          public void normalMethod() {}
      }
      """,
    ])

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.BothAnnotations"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @available(*, deprecated)
        #if compiler(>=6.3)
        @available(Android 28 /* Pie */, *)
        #endif
        @JavaMethod
        open func oldApi28Method()
        """,
        """
        @JavaMethod
        open func normalMethod()
        """,
      ]
    )
  }

  func testWrapJava_requiresApiOnClass() async throws {
    let classpathURL = try await compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java":
        """
      package androidx.annotation;
      import java.lang.annotation.*;
      @Retention(RetentionPolicy.RUNTIME)
      @Target({ElementType.TYPE, ElementType.METHOD, ElementType.CONSTRUCTOR, ElementType.FIELD})
      public @interface RequiresApi {
          int api() default 1;
          int value() default 1;
      }
      """,
      "com/example/TiramisuClass.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      @RequiresApi(api = 33)
      class TiramisuClass {
          public void doSomething() {}
      }
      """,
    ])

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.TiramisuClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 33 /* Tiramisu */, *)
        #endif
        @JavaClass("com.example.TiramisuClass")
        open class TiramisuClass: JavaObject {
        """
      ]
    )
  }
}

// MARK: - Multi-file Java compilation helper

/// Compiles multiple Java source files together, supporting different packages.
///
/// - Parameter sourceFiles: A dictionary mapping relative file paths
///   (e.g. `"androidx/annotation/RequiresApi.java"`) to their source text.
/// - Returns: The directory that should be added to the classpath.
private func compileJavaMultiFile(_ sourceFiles: [String: String]) async throws -> Foundation.URL {
  let baseDir = FileManager.default.temporaryDirectory
    .appendingPathComponent("swift-java-testing-\(UUID().uuidString)")
  let srcDir = baseDir.appendingPathComponent("src")
  let classesDir = baseDir.appendingPathComponent("classes")

  try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: classesDir, withIntermediateDirectories: true)

  var filePaths: [String] = []
  for (relativePath, source) in sourceFiles {
    let fileURL = srcDir.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try source.write(to: fileURL, atomically: true, encoding: .utf8)
    filePaths.append(fileURL.path)
  }

  var javacArguments: [String] = ["-d", classesDir.path]
  javacArguments.append(contentsOf: filePaths)

  let javacProcess = try await Subprocess.run(
    .path(.init("\(javaHome)" + "/bin/javac")),
    arguments: .init(javacArguments),
    output: .string(limit: Int.max, encoding: UTF8.self),
    error: .string(limit: Int.max, encoding: UTF8.self)
  )

  guard javacProcess.terminationStatus.isSuccess else {
    let outString = javacProcess.standardOutput ?? ""
    let errString = javacProcess.standardError ?? ""
    fatalError(
      "javac failed (\(javacProcess.terminationStatus));\nOUT: \(outString)\nERROR: \(errString)"
    )
  }

  print("Compiled java sources to: \(classesDir)")
  return classesDir
}
