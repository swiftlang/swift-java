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

import JavaNet
import JavaUtilJar
import Subprocess
@_spi(Testing) import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaShared
import SwiftJavaToolLib
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

final class BasicWrapJavaTests: XCTestCase {

  func testWrapJavaFromCompiledJavaSource() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class ExampleSimpleClass {}
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ExampleSimpleClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import SwiftJava
        import SwiftJavaJNICore
        """,
        """
        @JavaClass("com.example.ExampleSimpleClass")
        open class ExampleSimpleClass: JavaObject {
        """,
      ]
    )
  }

  func testWrapJava_docs_signature() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class ExampleSimpleClass {
        public void example(String name, int age) { }
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.ExampleSimpleClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        import SwiftJava
        import SwiftJavaJNICore
        """,
        """
          /// Java method `example`.
          ///
          /// ### Java method signature
          /// ```java
          /// public void com.example.ExampleSimpleClass.example(java.lang.String,int)
          /// ```
           @JavaMethod
           open func example(_ arg0: String, _ arg1: Int32)
        """,
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
      """
    )

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
        public void init() throws Exception {}
      }

      class SubClass extends SuperClass {
        public static final long serialVersionUID = 2L;
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.SuperClass",
        "com.example.SubClass",
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

  // Test that static fields are not duplicated when both a Java interface and its
  // super-interface independently declare the same field name.
  //
  // Real-world case: java.security.PublicKey extends java.security.Key, and both
  // declare serialVersionUID. Class.getFields() returns both Field objects (with
  // different declaring classes), which previously caused two @JavaStaticField
  // declarations to be emitted in extension JavaClass<PublicKey>.
  //
  // Note: uses real JDK classes rather than compileJava() — the duplicate only
  // manifests with JDK bytecode; freshly compiled interfaces apply stricter
  // field-hiding rules that prevent getFields() from returning both fields.
  //
  // The closing `}` in the expected chunk is load-bearing: if there are two
  // serialVersionUID declarations the `}` would be preceded by the second field,
  // not the first, so the chunk would not match.
  func test_wrapJava_noDuplicateStaticFieldsFromSuperInterface() async throws {
    let classpathURL = try await compileJava("class Dummy {}")
    try assertWrapJavaOutput(
      javaClassNames: [
        "java.security.Key",
        "java.security.PublicKey",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        // PublicKey should close its extension block right after one serialVersionUID.
        // A duplicate would insert a second field before the `}`, breaking this match.
        """
        extension JavaClass<PublicKey> {
        @available(*, deprecated)
        @JavaStaticField(isFinal: true)
        public var serialVersionUID: Int64
        }
        """
      ]
    )
  }

  // Test that Java methods named "init" get @JavaMethod("init") annotation.
  // Since "init" is a Swift keyword and gets escaped with backticks in the function name,
  // we explicitly specify the Java method name in the annotation.
  // See KeyAgreement.init() methods as a real-world example.
  func test_wrapJava_initMethodAnnotation() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      class TestClass {
        public void init(String arg) throws Exception {}
        public void init() throws Exception {}
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.TestClass"
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaMethod("init")
        open func `init`(_ arg0: String) throws
        """,
        """
        @JavaMethod("init")
        open func `init`() throws
        """,
      ]
    )
  }

  func test_wrapJava_inheritFromBiFunction() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;

      import java.util.function.BiFunction;

      interface CallMe<ValueType> extends BiFunction<ValueType, ValueType, ValueType> {
        @Override
        ValueType apply(
            ValueType newest,
            ValueType oldest
        );
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "java.util.function.BiFunction",
        "com.example.CallMe",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaInterface("com.example.CallMe", extends: BiFunction<JavaObject, JavaObject, JavaObject>.self)
        public struct CallMe<CallMe_ValueType: AnyJavaObject> {
          public typealias ValueType = CallMe_ValueType

          /// Java method `apply`.
          ///
          /// ### Java method signature
          /// ```java
          /// public abstract ValueType com.example.CallMe.apply(ValueType,ValueType)
          /// ```
          @JavaMethod(typeErasedResult: "ValueType!")
            public func apply(_ arg0: ValueType?, _ arg1: ValueType?) -> ValueType!
          }
        """
      ]
    )
  }

  func test_wrapJava_escapedSwiftName() async throws {
    let classpathURL = try await compileJava(
      """
      package com.example;
      
      class MyClass {
        public long init;
        public static boolean $foo; 
        public void func() {}
        public static void $bar() {}
      }
      """
    )

    try assertWrapJavaOutput(
      javaClassNames: [
        "com.example.MyClass",
      ],
      classpath: [classpathURL],
      expectedChunks: [
        """
        @JavaField("init", isFinal: false)
        public var `init`: Int64
        """,
        """
        @JavaStaticField("$foo", isFinal: false)
        public var _foo: Bool
        """,
        """
        @JavaMethod("func")
        open func `func`()
        """,
        """
        @JavaStaticMethod("$bar")
        public func _bar()
        """
      ]
    )
  }
}
