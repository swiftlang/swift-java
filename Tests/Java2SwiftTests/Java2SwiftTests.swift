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

import JavaKit
import Java2SwiftLib
import XCTest // NOTE: Workaround for https://github.com/swiftlang/swift-java/issues/43

/// Handy reference to the JVM abstraction.
var jvm: JavaVirtualMachine {
  get throws {
    try .shared()
  }
}

@JavaClass("java.time.Month")
public struct JavaMonth {}

@JavaClass("java.lang.ProcessBuilder")
struct ProcessBuilder {
  @JavaClass("java.lang.ProcessBuilder$Redirect")
  struct Redirect {
    @JavaClass("java.lang.ProcessBuilder$Redirect$Type")
    struct JavaType { }
  }
}

class Java2SwiftTests: XCTestCase {
  func testJavaLangObjectMapping() throws {
    try assertTranslatedClass(
      JavaObject.self,
      swiftTypeName: "MyJavaObject",
      expectedChunks: [
        "import JavaKit",
        """
        @JavaClass("java.lang.Object")
        public struct MyJavaObject {
        """,
        """
          @JavaMethod
          public func toString() -> String
        """,
        """
          @JavaMethod
          public func wait() throws
        """
      ]
    )
  }

  func testJavaLangClassMapping() throws {
    try assertTranslatedClass(
      JavaClass<JavaObject>.self,
      swiftTypeName: "MyJavaClass",
      translatedClasses: [
        "java.lang.Object": ("JavaObject", nil),
      ],
      expectedChunks: [
        "import JavaKit",
        """
        @JavaClass("java.lang.Class", extends: JavaObject.self)
        public struct MyJavaClass<T: AnyJavaObject> {
        """,
        """
          @JavaStaticMethod
          public func forName<T: AnyJavaObject>(_ arg0: String) throws -> MyJavaClass<JavaObject>! where ObjectType == MyJavaClass<T>
        """,
      ]
    )
  }

  func testEnum() throws {
    try assertTranslatedClass(
      JavaMonth.self,
      swiftTypeName: "Month",
      expectedChunks: [
        "import JavaKit",
        "enum MonthCases: Equatable",
        "case APRIL",
        "public var enumValue: MonthCases!",
        """
            } else if self.equals(classObj.APRIL?.as(JavaObject.self)) {
              return MonthCases.APRIL
            }
        """,
        "public init(_ enumValue: MonthCases, environment: JNIEnvironment? = nil) {",
        """
              case .APRIL:
                if let APRIL = classObj.APRIL {
                  self = APRIL
                } else {
                  fatalError("Enum value APRIL was unexpectedly nil, please re-run Java2Swift on the most updated Java class")
                }
        """,
        """
          @JavaStaticField(isFinal: true)
          public var APRIL: Month!
        """
      ])
  }

  func testGenericCollections() throws {
    try assertTranslatedClass(
      MyArrayList<JavaObject>.self,
      swiftTypeName: "JavaArrayList",
      translatedClasses: [
        "java.lang.Object": ("JavaObject", nil),
        "java.lang.reflect.Array": ("JavaArray", nil),
        "java.util.List": ("JavaList", nil),
        "java.util.function.IntFunction": ("MyJavaIntFunction", nil),
      ],
      expectedChunks: [
        """
          @JavaMethod
          public func subList(_ arg0: Int32, _ arg1: Int32) -> JavaList<JavaObject>!
        """,
        """
          @JavaMethod
          public func toArray(_ arg0: MyJavaIntFunction<JavaArray>?) -> [JavaObject?]
        """
      ]
    )
  }

  func testLinkedList() throws {
    try assertTranslatedClass(
      MyLinkedList<JavaObject>.self,
      swiftTypeName: "JavaLinkedList",
      translatedClasses: [
        "java.lang.Object": ("JavaObject", nil),
        "java.util.List": ("JavaList", nil),
      ],
      expectedChunks: [
        """
          @JavaMethod
          public func subList(_ arg0: Int32, _ arg1: Int32) -> JavaList<JavaObject>!
        """
      ]
    )
  }

  func testNestedSubclasses() throws {
    try assertTranslatedClass(
      ProcessBuilder.self,
      swiftTypeName: "ProcessBuilder",
      translatedClasses: [
        "java.lang.ProcessBuilder": ("ProcessBuilder", nil),
        "java.lang.ProcessBuilder$Redirect": ("ProcessBuilder.Redirect", nil),
        "java.lang.ProcessBuilder$Redirect$Type": ("ProcessBuilder.Redirect.Type", nil),
      ],
      nestedClasses: [
        "java.lang.ProcessBuilder": [JavaClass<ProcessBuilder.Redirect>().as(JavaClass<JavaObject>.self)!],
        "java.lang.ProcessBuilder$Redirect": [JavaClass<ProcessBuilder.Redirect.JavaType>().as(JavaClass<JavaObject>.self)!],
      ],
      expectedChunks: [
        "import JavaKit",
        """
          @JavaMethod
          public func redirectInput() -> ProcessBuilder.Redirect!
        """,
        """
        extension ProcessBuilder {
          @JavaClass("java.lang.ProcessBuilder$Redirect")
          public struct Redirect {
        """,
        """
        public func redirectError() -> ProcessBuilder.Redirect!
        """,
        """
        extension ProcessBuilder.Redirect {
          @JavaClass("java.lang.ProcessBuilder$Redirect$Type")
          public struct Type {
        """,
        """
          @JavaMethod
          public func type() -> ProcessBuilder.Redirect.`Type`!
        """,
      ]
    )
  }

  func testNestedRenamedSubclasses() throws {
    try assertTranslatedClass(
      ProcessBuilder.self,
      swiftTypeName: "ProcessBuilder",
      translatedClasses: [
        "java.lang.ProcessBuilder": ("ProcessBuilder", nil),
        "java.lang.ProcessBuilder$Redirect": ("ProcessBuilder.PBRedirect", nil),
        "java.lang.ProcessBuilder$Redirect$Type": ("ProcessBuilder.PBRedirect.JavaType", nil),
      ],
      nestedClasses: [
        "java.lang.ProcessBuilder": [JavaClass<ProcessBuilder.Redirect>().as(JavaClass<JavaObject>.self)!],
        "java.lang.ProcessBuilder$Redirect": [JavaClass<ProcessBuilder.Redirect.JavaType>().as(JavaClass<JavaObject>.self)!],
      ],
      expectedChunks: [
        "import JavaKit",
        """
          @JavaMethod
          public func redirectInput() -> ProcessBuilder.PBRedirect!
        """,
        """
        extension ProcessBuilder {
          @JavaClass("java.lang.ProcessBuilder$Redirect")
          public struct PBRedirect {
        """,
        """
        public func redirectError() -> ProcessBuilder.PBRedirect!
        """,
        """
        extension ProcessBuilder.PBRedirect {
          @JavaClass("java.lang.ProcessBuilder$Redirect$Type")
          public struct JavaType {
        """,
        """
          @JavaMethod
          public func type() -> ProcessBuilder.PBRedirect.JavaType!
        """
      ]
    )
  }

  func testJavaString() throws {
    try assertTranslatedClass(
      MyJavaString.self,
      swiftTypeName: "JavaString",
      expectedChunks: [
        """
        @JavaClass("java.lang.String")
        public struct JavaString {
        """
      ]
    )
  }

  func testJavaObjects() throws {
    try assertTranslatedClass(
      MyObjects.self,
      swiftTypeName: "MyJavaObjects",
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "JavaKit"),
        "java.util.function.Supplier" : ("MySupplier", "JavaKitFunction"),
        "java.lang.String" : ("JavaString", "JavaKit"),
      ],
      expectedChunks: [
        """
        import JavaKitFunction
        """,
        """
        @JavaClass("java.util.Objects", extends: JavaObject.self)
        public struct MyJavaObjects {
        """,
        """
          @JavaStaticMethod
          public func requireNonNull(_ arg0: JavaObject?, _ arg1: MySupplier<JavaString>?) -> JavaObject!
        """,
      ]
    )
  }
}

@JavaClass("java.util.ArrayList")
public struct MyArrayList<E: AnyJavaObject> {
}

@JavaClass("java.util.LinkedList")
public struct MyLinkedList<E: AnyJavaObject> {
}

@JavaClass("java.lang.String")
public struct MyJavaString {
}

@JavaClass("java.util.Objects")
public struct MyObjects { }

@JavaInterface("java.util.function.Supplier")
public struct MySupplier { }

@JavaInterface("java.util.function.IntFunction")
public struct MyJavaIntFunction<R: AnyJavaObject> {
}

/// Translate a Java class and assert that the translated output contains
/// each of the expected "chunks" of text.
func assertTranslatedClass<JavaClassType: AnyJavaObject>(
  _ javaType: JavaClassType.Type,
  swiftTypeName: String,
  translatedClasses: [
    String: (swiftType: String, swiftModule: String?)
  ] = [:],
  nestedClasses: [String: [JavaClass<JavaObject>]] = [:],
  expectedChunks: [String],
  file: StaticString = #filePath,
  line: UInt = #line
) throws {
  let environment = try jvm.environment()
  let translator = JavaTranslator(
    swiftModuleName: "SwiftModule",
    environment: environment
  )

  translator.translatedClasses = translatedClasses
  translator.translatedClasses[javaType.fullJavaClassName] = (swiftTypeName, nil)
  translator.nestedClasses = nestedClasses
  translator.startNewFile()
  let translatedDecls = try translator.translateClass(
    JavaClass<JavaObject>(
      javaThis: javaType.getJNIClass(in: environment),
      environment: environment)
  )
  let importDecls = translator.getImportDecls()

  let swiftFileText = """
    // Auto-generated by Java-to-Swift wrapper generator.
    \(importDecls.map { $0.description }.joined())
    \(translatedDecls.map { $0.description }.joined(separator: "\n"))
    """

  for expectedChunk in expectedChunks {
    if swiftFileText.contains(expectedChunk) {
      continue
    }

    XCTFail("Expected chunk '\(expectedChunk)' not found in '\(swiftFileText)'", file: file, line: line)
  }
}
