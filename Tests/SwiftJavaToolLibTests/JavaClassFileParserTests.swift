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
import XCTest

@testable import SwiftJavaToolLib

final class JavaClassFileParserTests: XCTestCase {

  /// Fake `@RequiresApi` annotation with CLASS retention, matching real AndroidX behavior.
  static let RequiresApi_ClassRetention = """
    package androidx.annotation;
    import java.lang.annotation.*;
    @Retention(RetentionPolicy.CLASS)
    @Target({ElementType.TYPE, ElementType.METHOD, ElementType.CONSTRUCTOR, ElementType.FIELD})
    public @interface RequiresApi {
        int api() default 1;
        int value() default 1;
    }
    """

  func test_parseClassAnnotation() async throws {
    let classesDir = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java":
        Self.RequiresApi_ClassRetention,
      "com/example/MyClass.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      @RequiresApi(api = 33)
      public class MyClass {
          public void hello() {}
      }
      """,
    ])

    let classFileURL = classesDir.appendingPathComponent("com/example/MyClass.class")
    let bytes = Array(try Data(contentsOf: classFileURL))
    let result = JavaClassFileReader.parseRuntimeInvisibleAnnotations(bytes)

    XCTAssertEqual(result.classAnnotations.count, 1)
    let annotation = result.classAnnotations[0]
    XCTAssertEqual(annotation.fullyQualifiedName, "androidx.annotation.RequiresApi")
    XCTAssertEqual(annotation.elements["api"], 33)
  }

  func test_parseMethodAnnotation() async throws {
    let classesDir = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java":
        Self.RequiresApi_ClassRetention,
      "com/example/MethodExample.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      public class MethodExample {
          @RequiresApi(api = 30)
          public void api30Method() {}
          public void normalMethod() {}
      }
      """,
    ])

    let classFileURL = classesDir.appendingPathComponent("com/example/MethodExample.class")
    let bytes = Array(try Data(contentsOf: classFileURL))
    let result = JavaClassFileReader.parseRuntimeInvisibleAnnotations(bytes)

    XCTAssertTrue(result.classAnnotations.isEmpty)

    // Find the annotated method by key prefix
    let api30Annotations = result.methodAnnotations.filter { $0.key.hasPrefix("api30Method:") }
    XCTAssertEqual(api30Annotations.count, 1)
    let annotations = api30Annotations.values.first!
    XCTAssertEqual(annotations.count, 1)
    XCTAssertEqual(annotations[0].fullyQualifiedName, "androidx.annotation.RequiresApi")
    XCTAssertEqual(annotations[0].elements["api"], 30)

    // normalMethod should have no annotations
    let normalAnnotations = result.methodAnnotations.filter { $0.key.hasPrefix("normalMethod:") }
    XCTAssertTrue(normalAnnotations.isEmpty)
  }

  func test_parseFieldAnnotation() async throws {
    let classesDir = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java":
        Self.RequiresApi_ClassRetention,
      "com/example/FieldExample.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      public class FieldExample {
          @RequiresApi(api = 28)
          public static int API_FIELD = 42;
          public static int NORMAL_FIELD = 99;
      }
      """,
    ])

    let classFileURL = classesDir.appendingPathComponent("com/example/FieldExample.class")
    let bytes = Array(try Data(contentsOf: classFileURL))
    let result = JavaClassFileReader.parseRuntimeInvisibleAnnotations(bytes)

    XCTAssertEqual(result.fieldAnnotations["API_FIELD"]?.count, 1)
    XCTAssertEqual(result.fieldAnnotations["API_FIELD"]?[0].fullyQualifiedName, "androidx.annotation.RequiresApi")
    XCTAssertEqual(result.fieldAnnotations["API_FIELD"]?[0].elements["api"], 28)
    XCTAssertNil(result.fieldAnnotations["NORMAL_FIELD"])
  }

  func test_parseConstructorAnnotation() async throws {
    let classesDir = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java":
        Self.RequiresApi_ClassRetention,
      "com/example/CtorExample.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      public class CtorExample {
          @RequiresApi(api = 31)
          public CtorExample() {}
      }
      """,
    ])

    let classFileURL = classesDir.appendingPathComponent("com/example/CtorExample.class")
    let bytes = Array(try Data(contentsOf: classFileURL))
    let result = JavaClassFileReader.parseRuntimeInvisibleAnnotations(bytes)

    let ctorAnnotations = result.methodAnnotations.filter { $0.key.hasPrefix("<init>:") }
    XCTAssertEqual(ctorAnnotations.count, 1)
    let annotations = ctorAnnotations.values.first!
    XCTAssertEqual(annotations.count, 1)
    XCTAssertEqual(annotations[0].fullyQualifiedName, "androidx.annotation.RequiresApi")
    XCTAssertEqual(annotations[0].elements["api"], 31)
  }

  func test_parseValueElement() async throws {
    let classesDir = try await CompileJavaTool.compileJavaMultiFile([
      "androidx/annotation/RequiresApi.java":
        Self.RequiresApi_ClassRetention,
      "com/example/ValueExample.java":
        """
      package com.example;
      import androidx.annotation.RequiresApi;
      @RequiresApi(value = 26)
      public class ValueExample {}
      """,
    ])

    let classFileURL = classesDir.appendingPathComponent("com/example/ValueExample.class")
    let bytes = Array(try Data(contentsOf: classFileURL))
    let result = JavaClassFileReader.parseRuntimeInvisibleAnnotations(bytes)

    XCTAssertEqual(result.classAnnotations.count, 1)
    XCTAssertEqual(result.classAnnotations[0].elements["value"], 26)
    // "api" should not be present (or default to 1, but javac omits defaults)
    XCTAssertNil(result.classAnnotations[0].elements["api"])
  }

  func test_noRuntimeAnnotations() async throws {
    let classesDir = try await CompileJavaTool.compileJavaMultiFile([
      "com/example/PlainClass.java":
        """
      package com.example;
      public class PlainClass {
          @Deprecated
          public void oldMethod() {}
          public void newMethod() {}
      }
      """
    ])

    let classFileURL = classesDir.appendingPathComponent("com/example/PlainClass.class")
    let bytes = Array(try Data(contentsOf: classFileURL))
    let result = JavaClassFileReader.parseRuntimeInvisibleAnnotations(bytes)

    // @Deprecated has RUNTIME retention, so it won't appear in RuntimeInvisibleAnnotations
    XCTAssertTrue(result.classAnnotations.isEmpty)
    XCTAssertTrue(result.methodAnnotations.isEmpty)
    XCTAssertTrue(result.fieldAnnotations.isEmpty)
  }

  func test_invalidMagic() {
    let bytes: [UInt8] = [0x00, 0x12, 0x34, 0x00]
    let result = JavaClassFileReader.parseRuntimeInvisibleAnnotations(bytes)

    XCTAssertTrue(result.classAnnotations.isEmpty)
    XCTAssertTrue(result.methodAnnotations.isEmpty)
    XCTAssertTrue(result.fieldAnnotations.isEmpty)
  }
}
