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
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

@testable import SwiftJavaToolLib

/// Tests for `@available` attribute generation from Android `api-versions.xml` data.
final class AndroidAPIVersionsWrapJavaTests: XCTestCase {

  /// Java source for a CLASS-retention `@RequiresApi` annotation,
  /// matching real AndroidX behavior.
  static let requiresApiAnnotationSource = """
    package androidx.annotation;
    import java.lang.annotation.*;
    @Retention(RetentionPolicy.CLASS)
    @Target({ElementType.TYPE, ElementType.METHOD, ElementType.CONSTRUCTOR, ElementType.FIELD})
    public @interface RequiresApi {
        int api() default 1;
        int value() default 1;
    }
    """

  // ==== ------------------------------------------------
  // MARK: since

  func testWrapJava_androidAPIVersions_sinceOnClass() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public class VersionedClass {
          public void doWork() {}
      }
      """
    )

    var apiVersions = AndroidAPIVersions()
    apiVersions.classVersions["com.example.VersionedClass"] = AndroidAPIAvailability(since: .LOLLIPOP)

    try assertWrapJavaOutput(
      javaClassNames: ["com.example.VersionedClass"],
      classpath: [classpathURL],
      androidAPIVersions: apiVersions,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 21 /* Lollipop */, *)
        #endif
        @JavaClass("com.example.VersionedClass")
        open class VersionedClass: JavaObject {
        """
      ]
    )
  }

  func testWrapJava_androidAPIVersions_sinceOnMethod() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public class MethodVersioned {
          public void newMethod() {}
          public void oldMethod() {}
      }
      """
    )

    var apiVersions = AndroidAPIVersions()
    apiVersions.classVersions["com.example.MethodVersioned"] = AndroidAPIAvailability(since: .BASE)
    apiVersions.methodVersions["com.example.MethodVersioned"] = [
      "newMethod()V": AndroidAPIAvailability(since: .TIRAMISU)
    ]

    try assertWrapJavaOutput(
      javaClassNames: ["com.example.MethodVersioned"],
      classpath: [classpathURL],
      androidAPIVersions: apiVersions,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 33 /* Tiramisu */, *)
        #endif
        @JavaMethod
        open func newMethod()
        """,
        """
        @JavaMethod
        open func oldMethod()
        """,
      ]
    )
  }

  // ==== ------------------------------------------------
  // MARK: deprecated

  func testWrapJava_androidAPIVersions_deprecatedMethod() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public class DeprecatedByVersions {
          public void stableMethod() {}
          public void deprecatedMethod() {}
      }
      """
    )

    var apiVersions = AndroidAPIVersions()
    apiVersions.classVersions["com.example.DeprecatedByVersions"] = AndroidAPIAvailability(since: .BASE)
    apiVersions.methodVersions["com.example.DeprecatedByVersions"] = [
      "deprecatedMethod()V": AndroidAPIAvailability(since: .ECLAIR, deprecated: .P)
    ]

    try assertWrapJavaOutput(
      javaClassNames: ["com.example.DeprecatedByVersions"],
      classpath: [classpathURL],
      androidAPIVersions: apiVersions,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 5 /* Eclair */, *)
        #endif
        #if compiler(>=6.3)
        @available(Android, deprecated: 28, message: "Deprecated in Android API 28 /* Pie */")
        #endif
        @JavaMethod
        open func deprecatedMethod()
        """,
        """
        @JavaMethod
        open func stableMethod()
        """,
      ]
    )
  }

  func testWrapJava_androidAPIVersions_deprecatedClass() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public class OldVersionedClass {
          public void doWork() {}
      }
      """
    )

    var apiVersions = AndroidAPIVersions()
    apiVersions.classVersions["com.example.OldVersionedClass"] = AndroidAPIAvailability(
      since: .CUPCAKE,
      deprecated: .Q
    )

    try assertWrapJavaOutput(
      javaClassNames: ["com.example.OldVersionedClass"],
      classpath: [classpathURL],
      androidAPIVersions: apiVersions,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 3 /* Cupcake */, *)
        #endif
        #if compiler(>=6.3)
        @available(Android, deprecated: 29, message: "Deprecated in Android API 29 /* Android 10 */")
        #endif
        @JavaClass("com.example.OldVersionedClass")
        open class OldVersionedClass: JavaObject {
        """
      ]
    )
  }

  // ==== ------------------------------------------------
  // MARK: removed

  func testWrapJava_androidAPIVersions_removedMethod() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public class RemovedByVersions {
          public void removedMethod() {}
          public void activeMethod() {}
      }
      """
    )

    var apiVersions = AndroidAPIVersions()
    apiVersions.classVersions["com.example.RemovedByVersions"] = AndroidAPIAvailability(since: .BASE)
    apiVersions.methodVersions["com.example.RemovedByVersions"] = [
      "removedMethod()V": AndroidAPIAvailability(since: .CUPCAKE, removed: .P)
    ]

    try assertWrapJavaOutput(
      javaClassNames: ["com.example.RemovedByVersions"],
      classpath: [classpathURL],
      androidAPIVersions: apiVersions,
      expectedChunks: [
        // Removed APIs emit deprecated instead of unavailable, since Swift's 'unavailable' doesn't accept a version
        """
        #if compiler(>=6.3)
        @available(Android, deprecated: 28, message: "Removed in Android API 28 /* Pie */")
        #endif
        @JavaMethod
        open func removedMethod()
        """,
        """
        @JavaMethod
        open func activeMethod()
        """,
      ]
    )
  }

  func testWrapJava_androidAPIVersions_removedAndDeprecated() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public class DeprecatedThenRemoved {
          public void goneMethod() {}
      }
      """
    )

    var apiVersions = AndroidAPIVersions()
    apiVersions.classVersions["com.example.DeprecatedThenRemoved"] = AndroidAPIAvailability(since: .BASE)
    apiVersions.methodVersions["com.example.DeprecatedThenRemoved"] = [
      "goneMethod()V": AndroidAPIAvailability(since: .CUPCAKE, removed: .P, deprecated: .ICE_CREAM_SANDWICH_MR1)
    ]

    try assertWrapJavaOutput(
      javaClassNames: ["com.example.DeprecatedThenRemoved"],
      classpath: [classpathURL],
      androidAPIVersions: apiVersions,
      expectedChunks: [
        // deprecated is emitted; removed doesn't add a second deprecated since one already exists
        """
        #if compiler(>=6.3)
        @available(Android, deprecated: 15, message: "Deprecated in Android API 15 /* Ice Cream Sandwich MR1 */")
        #endif
        @JavaMethod
        open func goneMethod()
        """
      ]
    )
  }

  // ==== ------------------------------------------------
  // MARK: fields

  func testWrapJava_androidAPIVersions_fieldSinceAndDeprecated() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      public class FieldVersioned {
          public static int NEW_FIELD = 1;
          public static int OLD_FIELD = 2;
      }
      """
    )

    var apiVersions = AndroidAPIVersions()
    apiVersions.classVersions["com.example.FieldVersioned"] = AndroidAPIAvailability(since: .BASE)
    apiVersions.fieldVersions["com.example.FieldVersioned"] = [
      "NEW_FIELD": AndroidAPIAvailability(since: .P),
      "OLD_FIELD": AndroidAPIAvailability(since: .ECLAIR, deprecated: .M),
    ]

    try assertWrapJavaOutput(
      javaClassNames: ["com.example.FieldVersioned"],
      classpath: [classpathURL],
      androidAPIVersions: apiVersions,
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 28 /* Pie */, *)
        #endif
        @JavaStaticField(isFinal: false)
        public var NEW_FIELD: Int32
        """,
        """
        #if compiler(>=6.3)
        @available(Android 5 /* Eclair */, *)
        #endif
        #if compiler(>=6.3)
        @available(Android, deprecated: 23, message: "Deprecated in Android API 23 /* Marshmallow */")
        #endif
        @JavaStaticField(isFinal: false)
        public var OLD_FIELD: Int32
        """,
      ]
    )
  }

  // ==== ------------------------------------------------
  // MARK: interaction with @RequiresApi

  func testWrapJava_androidAPIVersions_doesNotOverrideRequiresApi() async throws {
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
      "com/example/MixedSources.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;

      public class MixedSources {
          @RequiresApi(api = 30)
          public void annotatedMethod() {}
      }
      """,
    ])

    // api-versions.xml says since=21, but @RequiresApi(30) should win
    var apiVersions = AndroidAPIVersions()
    apiVersions.classVersions["com.example.MixedSources"] = AndroidAPIAvailability(since: .BASE)
    apiVersions.methodVersions["com.example.MixedSources"] = [
      "annotatedMethod()V": AndroidAPIAvailability(since: .LOLLIPOP)
    ]

    try assertWrapJavaOutput(
      javaClassNames: ["com.example.MixedSources"],
      classpath: [classpathURL],
      androidAPIVersions: apiVersions,
      expectedChunks: [
        // @RequiresApi(30) wins, api-versions since=21 is NOT duplicated
        """
        #if compiler(>=6.3)
        @available(Android 30 /* Android 11 */, *)
        #endif
        @JavaMethod
        open func annotatedMethod()
        """
      ]
    )
  }
}
