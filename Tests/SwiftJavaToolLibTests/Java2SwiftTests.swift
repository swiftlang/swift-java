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

@_spi(Testing)
import SwiftJava
import SwiftJavaToolLib
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
        "import SwiftJava",
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
        "import SwiftJava",
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
        "import SwiftJava",
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
        "import SwiftJava",
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
        "import SwiftJava",
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
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
        "java.util.function.Supplier" : ("MySupplier", "JavaUtilFunction"),
        "java.lang.String" : ("JavaString", "SwiftJava"),
      ],
      expectedChunks: [
        """
        import JavaUtilFunction
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

  func testJavaLangObjectMappingAsClass() throws {
    try assertTranslatedClass(
      JavaObject.self,
      swiftTypeName: "JavaObject",
      asClass: true,
      expectedChunks: [
        "import SwiftJava",
        """
        @JavaClass("java.lang.Object")
        open class JavaObject {
        """,
        """
          @JavaMethod
          @_nonoverride public convenience init(environment: JNIEnvironment? = nil)
        """,
        """
          @JavaMethod
          open func toString() -> String
        """,
        """
          @JavaMethod
          open func wait() throws
        """,
        """
          @JavaMethod
          open func clone() throws -> JavaObject!
        """,
      ]
    )
  }

  func testJavaLangStringMappingAsClass() throws {
    try assertTranslatedClass(
      JavaString.self,
      swiftTypeName: "JavaString",
      asClass: true,
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
      ],
      expectedChunks: [
        "import SwiftJava",
        """
        @JavaClass("java.lang.String")
        open class JavaString: JavaObject {
        """,
        """
          @JavaMethod
          @_nonoverride public convenience init(environment: JNIEnvironment? = nil)
        """,
        """
          @JavaMethod
          open override func toString() -> String
        """,
        """
          @JavaMethod
          open override func equals(_ arg0: JavaObject?) -> Bool
        """,
        """
          @JavaMethod
          open func intern() -> String
        """,
        """
          @JavaStaticMethod
          public func valueOf(_ arg0: Int64) -> String
        """,
      ]
    )
  }

  func testEnumAsClass() throws {
    try assertTranslatedClass(
      JavaMonth.self,
      swiftTypeName: "Month",
      asClass: true,
      expectedChunks: [
        "import SwiftJava",
        "enum MonthCases: Equatable",
        "case APRIL",
        "public var enumValue: MonthCases!",
        """
            } else if self.equals(classObj.APRIL?.as(JavaObject.self)) {
              return MonthCases.APRIL
            }
        """,
        "public convenience init(_ enumValue: MonthCases, environment: JNIEnvironment? = nil) {",
        """
        let classObj = try! JavaClass<Month>(environment: _environment)
        """,
        """
              case .APRIL:
                if let APRIL = classObj.APRIL {
                  self.init(javaHolder: APRIL.javaHolder)
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

  func testURLLoaderSkipMappingAsClass() throws {
    // URLClassLoader actually inherits from SecureClassLoader. However,
    // that type wasn't mapped into Swift, so we find the nearest
    // superclass that was mapped into Swift.
    try assertTranslatedClass(
      URLClassLoader.self,
      swiftTypeName: "URLClassLoader",
      asClass: true,
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
        "java.lang.ClassLoader" : ("ClassLoader", "SwiftJava"),
        "java.net.URL" : ("URL", "JavaNet"),
      ],
      expectedChunks: [
        "import SwiftJava",
        """
        @JavaClass("java.net.URLClassLoader")
        open class URLClassLoader: ClassLoader {
        """,
        """
          @JavaMethod
          open func close() throws
        """,
        """
          @JavaMethod
          open override func findResource(_ arg0: String) -> URL!
        """,
      ]
    )
  }

  func testURLLoaderSkipTwiceMappingAsClass() throws {
    // URLClassLoader actually inherits from SecureClassLoader. However,
    // that type wasn't mapped into Swift here, nor is ClassLoader,
    // so we fall back to JavaObject.
    try assertTranslatedClass(
      URLClassLoader.self,
      swiftTypeName: "URLClassLoader",
      asClass: true,
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
        "java.net.URL" : ("URL", "JavaNet"),
      ],
      expectedChunks: [
        "import SwiftJava",
        """
        @JavaClass("java.net.URLClassLoader")
        open class URLClassLoader: JavaObject {
        """,
        """
          @JavaMethod
          open func close() throws
        """,
        """
          @JavaMethod
          open func findResource(_ arg0: String) -> URL!
        """,
      ]
    )
  }

  func testOverrideSkipImmediateSuperclass() throws {
    // JavaByte overrides equals() from JavaObject, which it indirectly
    // inherits through JavaNumber
    try assertTranslatedClass(
      JavaByte.self,
      swiftTypeName: "JavaByte",
      asClass: true,
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
        "java.lang.Number" : ("JavaNumber", "SwiftJava"),
        "java.lang.Byte" : ("JavaByte", "SwiftJava"),
      ],
      expectedChunks: [
        "import SwiftJava",
        """
        @JavaClass("java.lang.Byte")
        open class JavaByte: JavaNumber {
        """,
        """
          @JavaMethod
          open override func equals(_ arg0: JavaObject?) -> Bool
        """,
      ]
    )
  }

  func testJavaInterfaceAsClassNOT() throws {
    try assertTranslatedClass(
      MyJavaIntFunction<JavaObject>.self,
      swiftTypeName: "MyJavaIntFunction",
      asClass: true,
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
        "java.util.function.IntFunction": ("MyJavaIntFunction", nil),
      ],
      expectedChunks: [
        "import SwiftJava",
        """
        @JavaInterface("java.util.function.IntFunction")
        public struct MyJavaIntFunction<R: AnyJavaObject> {
        """,
        """
          @JavaMethod
          public func apply(_ arg0: Int32) -> JavaObject!
        """,
      ]
    )
  }

  func testCovariantInJavaNotInSwiftOverride() throws {
    try assertTranslatedClass(
      Method.self,
      swiftTypeName: "Method",
      asClass: true,
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
        "java.lang.Class" : ("JavaClass", "SwiftJava"),
        "java.lang.reflect.Executable": ("Executable", "JavaLangReflect"),
        "java.lang.reflect.Method": ("Method", "JavaLangReflect"),
        "java.lang.reflect.TypeVariable" : ("TypeVariable", "JavaLangReflect"),
      ],
      expectedChunks: [
        "import JavaLangReflect",
        """
        @JavaClass("java.lang.reflect.Method")
        open class Method: Executable {
        """,
        """
          @JavaMethod
          open func getTypeParameters() -> [TypeVariable<Method>?]
        """,
        """
          @JavaMethod
          open override func getParameterTypes() -> [JavaClass<JavaObject>?]
        """,
        """
          @JavaMethod
          open override func getDeclaringClass() -> JavaClass<JavaObject>!
        """,
      ]
    )
  }

  func testCovariantInJavaNotInSwiftOverride2() throws {
    try assertTranslatedClass(
      Constructor.self,
      swiftTypeName: "Constructor",
      asClass: true,
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
        "java.lang.Class" : ("JavaClass", "SwiftJava"),
        "java.lang.reflect.Executable": ("Executable", "JavaLangReflect"),
        "java.lang.reflect.Method": ("Method", "JavaLangReflect"),
        "java.lang.reflect.TypeVariable" : ("TypeVariable", "JavaLangReflect"),
      ],
      expectedChunks: [
        "import JavaLangReflect",
        """
        @JavaClass("java.lang.reflect.Constructor")
        open class Constructor<T: AnyJavaObject>: Executable {
        """,
        """
          @JavaMethod
          open func getTypeParameters() -> [TypeVariable<Constructor<JavaObject>>?]
        """,
        """
          @JavaMethod
          open override func getParameterTypes() -> [JavaClass<JavaObject>?]
        """,
        """
          @JavaMethod
          open override func getDeclaringClass() -> JavaClass<JavaObject>!
        """,
      ]
    )
  }

  func testCovariantInJavaNotInSwiftOverride3() throws {
    try assertTranslatedClass(
      NIOByteBuffer.self,
      swiftTypeName: "NIOByteBuffer",
      asClass: true,
      translatedClasses: [
        "java.lang.Object" : ("JavaObject", "SwiftJava"),
        "java.lang.Class" : ("JavaClass", "SwiftJava"),
        "java.nio.Buffer": ("NIOBuffer", "JavaNio"),
        "java.nio.ByteBuffer": ("NIOByteBuffer", "JavaNio"),
      ],
      expectedChunks: [
        "import JavaNio",
        """
        @JavaClass("java.nio.ByteBuffer")
        open class NIOByteBuffer: NIOBuffer {
        """,
        """
          @JavaMethod
          open func array() -> [Int8]
        """,
        """
          @JavaMethod
          open override func arrayOffset() -> Int32
        """,
      ]
    )
  }
}

@JavaClass("java.lang.ClassLoader")
public struct ClassLoader { }

@JavaClass("java.security.SecureClassLoader")
public struct SecureClassLoader { }

@JavaClass("java.net.URLClassLoader")
public struct URLClassLoader { }


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

@JavaClass("java.lang.reflect.Method", extends: Executable.self)
public struct Method {
}

@JavaClass("java.lang.reflect.Constructor", extends: Executable.self)
public struct Constructor {
}

@JavaClass("java.lang.reflect.Executable")
public struct Executable {
}

@JavaInterface("java.lang.reflect.TypeVariable")
public struct TypeVariable<D: AnyJavaObject> {
}

@JavaClass("java.nio.Buffer")
open class NIOBuffer: JavaObject {

}

@JavaClass("java.nio.ByteBuffer")
open class NIOByteBuffer: NIOBuffer {

}

/// Translate a Java class and assert that the translated output contains
/// each of the expected "chunks" of text.
func assertTranslatedClass<JavaClassType: AnyJavaObject>(
  _ javaType: JavaClassType.Type,
  swiftTypeName: String,
  asClass: Bool = false,
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
    environment: environment,
    translateAsClass: asClass
  )

  translator.translatedClasses = translatedClasses
  translator.translatedClasses[javaType.fullJavaClassName] = (swiftTypeName, nil)
  translator.nestedClasses = nestedClasses
  translator.startNewFile()

  try javaType.withJNIClass(in: environment) { javaClass in
    let translatedDecls = try translator.translateClass(
      JavaClass<JavaObject>(
        javaThis: javaClass,
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
}
