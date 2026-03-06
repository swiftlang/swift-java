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
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
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

  func testWrapJava_requiresApiMethod_fromJar() async throws {
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
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
      makeJar: true,
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

  func testWrapJava_requiresApiField() async throws {
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
      "com/example/ApiFieldExample.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      class ApiFieldExample {
          @RequiresApi(api = 30)
          public static int API30_FIELD = 42;
          public static int NORMAL_FIELD = 99;
      }
      """,
    ])

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ApiFieldExample"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 30 /* Android 11 */, *)
        #endif
        @JavaStaticField(isFinal: false)
        public var API30_FIELD: Int32
        """,
        """
        @JavaStaticField(isFinal: false)
        public var NORMAL_FIELD: Int32
        """,
      ]
    )
  }

  func testWrapJava_requiresApiConstructor() async throws {
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
      "com/example/ApiConstructorExample.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      class ApiConstructorExample {
          @RequiresApi(api = 33)
          public ApiConstructorExample() {}
      }
      """,
    ])

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ApiConstructorExample"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 33 /* Tiramisu */, *)
        #endif
        @JavaMethod
        @_nonoverride public convenience init(environment: JNIEnvironment? = nil)
        """
      ]
    )
  }

  // ==== ------------------------------------------------
  // MARK: @Deprecated + @RequiresApi

  func testWrapJava_deprecatedAndRequiresApi() async throws {
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
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
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
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

  func testWrapJava_requiresApiSameSimpleNameDifferentPackages() async throws {
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
      "com/example/Example.java":
        """
      package com.example;

      public class Example {
          @androidx.annotation.RequiresApi(api = 28)
          public void doWork() {}
      }
      """,
      "com/another/Example.java":
        """
      package com.another;
      public class Example {
          @androidx.annotation.RequiresApi(api = 33)
          public void doWork() {}
      }
      """,
    ])

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.Example",
        "com.another.Example",
      ],
      classNameMappings: [
        "com.example.Example": "ExampleOne",
        "com.another.Example": "ExampleTwo",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        // com.example.Example — API 28
        """
        @JavaClass("com.example.Example")
        open class ExampleOne: JavaObject {
        """,
        """
        #if compiler(>=6.3)
        @available(Android 28 /* Pie */, *)
        #endif
        @JavaMethod
        open func doWork()
        """,
        // com.another.Example — API 33
        """
        @JavaClass("com.another.Example")
        open class ExampleTwo: JavaObject {
        """,
        """
        #if compiler(>=6.3)
        @available(Android 33 /* Tiramisu */, *)
        #endif
        @JavaMethod
        open func doWork()
        """,
      ]
    )
  }

  func testWrapJava_requiresApiOnSpecificMethod() async throws {
    let classpathURL = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java": Self.requiresApiAnnotationSource,
      "com/example/TiramisuClass.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;

      class TiramisuClass {
          @RequiresApi(api = 11)
          public void doSomething(String name) {}

          @RequiresApi(api = 33)
          public void doSomething() {}
      }
      """,
    ])

    // Only the specific overload gets the annotation
    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.TiramisuClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        #if compiler(>=6.3)
        @available(Android 11 /* Honeycomb */, *)
        #endif
        @JavaMethod
        open func doSomething(_ arg0: String)
        """,
        """
        #if compiler(>=6.3)
        @available(Android 33 /* Tiramisu */, *)
        #endif
        @JavaMethod
        open func doSomething()
        """,
      ]
    )
  }
}
