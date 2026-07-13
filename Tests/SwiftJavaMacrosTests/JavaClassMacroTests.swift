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

import SwiftJavaMacros
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

class JavaKitMacroTests: XCTestCase {
  static let javaKitMacros: [String: any Macro.Type] = [
    "JavaClass": JavaClassMacro.self,
    "JavaRecord": JavaClassMacro.self,
    "JavaInterface": JavaClassMacro.self,
    "JavaMethod": JavaMethodMacro.self,
    "JavaField": JavaFieldMacro.self,
    "JavaStaticMethod": JavaMethodMacro.self,
    "JavaStaticField": JavaFieldMacro.self,
  ]

  func testJavaStaticMethodFailure() throws {
    assertMacroExpansion(
      """
        @JavaClass("org.swift.example.HelloWorld")
        public class HelloWorld {
          @JavaStaticField
          public var test: String
        }
      """,
      expandedSource: """

          public class HelloWorld {
            public var test: String

              /// The full Java class name for this Swift type.
              open override class var fullJavaClassName: String {
                #if os(Android) && AndroidCoreLibraryDesugaring
                  AndroidSupport.androidDesugarClassNameConversion(for: "org.swift.example.HelloWorld")
                #else
                  "org.swift.example.HelloWorld"
                #endif
              }

              public required init(javaHolder: JavaObjectHolder) {
                  super.init(javaHolder: javaHolder)
              }
          }
        """,
      diagnostics: [
        DiagnosticSpec(message: "Cannot use @JavaStaticField outside of a JavaClass instance", line: 3, column: 5)
      ],
      macros: Self.javaKitMacros
    )
  }

  func testJavaStaticMethodSuccess() throws {
    assertMacroExpansion(
      """
        extension JavaClass<HelloWorld> {
          @JavaStaticField
          public var test: String
        }
      """,
      expandedSource: """

          extension JavaClass<HelloWorld> {
            public var test: String {
                get {
                    self[javaFieldName: "test", fieldType: String.self]
                }
                set {
                    self[javaFieldName: "test", fieldType: String.self] = newValue
                }
            }
          }
        """,
      macros: Self.javaKitMacros
    )
  }

  func testJavaClass() throws {
    assertMacroExpansion(
      """
        @JavaClass("org.swift.example.HelloWorld")
        public struct HelloWorld {
          @JavaMethod
          public init(environment: JNIEnvironment? = nil)

          @JavaMethod
          public init(_ value: Int32, environment: JNIEnvironment? = nil)

          @JavaMethod
          public func isBigEnough(_ v: Int32) -> Bool

          @JavaField
          public var myField: Int64

          @JavaField
          public var objectField: JavaObject!

          @JavaField(isFinal: true)
          public var myFinalField: Int64
        }
      """,
      expandedSource: """

          public struct HelloWorld {
            public init(environment: JNIEnvironment? = nil) {
                let _environment = if let environment {
                    environment
                } else {
                    try! JavaVirtualMachine.shared().environment()
                }
                self = try! Self.dynamicJavaNewObject(in: _environment)
            }
            public init(_ value: Int32, environment: JNIEnvironment? = nil) {
                let _environment = if let environment {
                    environment
                } else {
                    try! JavaVirtualMachine.shared().environment()
                }
                self = try! Self.dynamicJavaNewObject(in: _environment, arguments: value.self)
            }
            public func isBigEnough(_ v: Int32) -> Bool {
                return {
                  do {
                    return try dynamicJavaMethodCall(methodName: "isBigEnough", arguments: v, resultType: Bool.self)
                  } catch {
                    if let throwable = error as? Throwable {
                  let sw = StringWriter()
                  let pw = PrintWriter(sw)
                  throwable.printStackTrace(pw)
                  fatalError("Java call threw unhandled exception: \\(error)\\n\\(sw.toString())")
                    }
                    fatalError("Java call threw unhandled exception: \\(error)")
                  }
                }()
            }
            public var myField: Int64 {
                get {
                    self[javaFieldName: "myField", fieldType: Int64.self]
                }
                nonmutating set {
                    self[javaFieldName: "myField", fieldType: Int64.self] = newValue
                }
            }
            public var objectField: JavaObject! {
                get {
                    self[javaFieldName: "objectField", fieldType: JavaObject?.self]
                }
                nonmutating set {
                    self[javaFieldName: "objectField", fieldType: JavaObject?.self] = newValue
                }
            }
            public var myFinalField: Int64 {
                get {
                    self[javaFieldName: "myFinalField", fieldType: Int64.self]
                }
            }

              /// The full Java class name for this Swift type.
              public static var fullJavaClassName: String {
                #if os(Android) && AndroidCoreLibraryDesugaring
                  AndroidSupport.androidDesugarClassNameConversion(for: "org.swift.example.HelloWorld")
                #else
                  "org.swift.example.HelloWorld"
                #endif
              }

              public typealias JavaSuperclass = JavaObject

              public var javaHolder: JavaObjectHolder

              public init(javaHolder: JavaObjectHolder) {
                  self.javaHolder = javaHolder
              }

              /// Casting to ``JavaObject`` will never be nil because ``HelloWorld`` extends it.
              public func `as`(_: JavaObject.Type) -> JavaObject {
                  return JavaObject(javaHolder: javaHolder)
              }
          }
        """,
      macros: Self.javaKitMacros
    )
  }

  func testJavaClassAsClass() throws {
    assertMacroExpansion(
      """
        @JavaClass("org.swift.example.HelloWorld")
        public class HelloWorld: OtherJavaType {
          @JavaMethod
          public init(environment: JNIEnvironment? = nil)

          @JavaMethod
          public init(_ value: Int32, environment: JNIEnvironment? = nil)

          @JavaMethod
          public func isBigEnough(_ v: Int32) -> Bool

          @JavaField
          public var myField: Int64

          @JavaField
          public var objectField: JavaObject!

          @JavaField(isFinal: true)
          public var myFinalField: Int64
        }
      """,
      expandedSource: """

          public class HelloWorld: OtherJavaType {
            public init(environment: JNIEnvironment? = nil) {
                let _environment = if let environment {
                    environment
                } else {
                    try! JavaVirtualMachine.shared().environment()
                }
                let javaThis = try! Self.dynamicJavaNewObjectInstance(in: _environment)
                self.init(javaThis: javaThis, environment: _environment)
            }
            public init(_ value: Int32, environment: JNIEnvironment? = nil) {
                let _environment = if let environment {
                    environment
                } else {
                    try! JavaVirtualMachine.shared().environment()
                }
                let javaThis = try! Self.dynamicJavaNewObjectInstance(in: _environment, arguments: value.self)
                self.init(javaThis: javaThis, environment: _environment)
            }
            public func isBigEnough(_ v: Int32) -> Bool {
                return {
                  do {
                    return try dynamicJavaMethodCall(methodName: "isBigEnough", arguments: v, resultType: Bool.self)
                  } catch {
                    if let throwable = error as? Throwable {
                  let sw = StringWriter()
                  let pw = PrintWriter(sw)
                  throwable.printStackTrace(pw)
                  fatalError("Java call threw unhandled exception: \\(error)\\n\\(sw.toString())")
                    }
                    fatalError("Java call threw unhandled exception: \\(error)")
                  }
                }()
            }
            public var myField: Int64 {
                get {
                    self[javaFieldName: "myField", fieldType: Int64.self]
                }
                set {
                    self[javaFieldName: "myField", fieldType: Int64.self] = newValue
                }
            }
            public var objectField: JavaObject! {
                get {
                    self[javaFieldName: "objectField", fieldType: JavaObject?.self]
                }
                set {
                    self[javaFieldName: "objectField", fieldType: JavaObject?.self] = newValue
                }
            }
            public var myFinalField: Int64 {
                get {
                    self[javaFieldName: "myFinalField", fieldType: Int64.self]
                }
            }

              /// The full Java class name for this Swift type.
              open override class var fullJavaClassName: String {
                #if os(Android) && AndroidCoreLibraryDesugaring
                  AndroidSupport.androidDesugarClassNameConversion(for: "org.swift.example.HelloWorld")
                #else
                  "org.swift.example.HelloWorld"
                #endif
              }

              public required init(javaHolder: JavaObjectHolder) {
                  super.init(javaHolder: javaHolder)
              }
          }
        """,
      macros: Self.javaKitMacros
    )
  }

  func testJavaObjectAsClass() throws {
    assertMacroExpansion(
      """
        @JavaClass("java.lang.Object")
        public class JavaObject {
          @JavaMethod
          public init(environment: JNIEnvironment? = nil)

          @JavaMethod
          public func isBigEnough(_ v: Int32) -> Bool
        }
      """,
      expandedSource: """

          public class JavaObject {
            public init(environment: JNIEnvironment? = nil) {
                let _environment = if let environment {
                    environment
                } else {
                    try! JavaVirtualMachine.shared().environment()
                }
                let javaThis = try! Self.dynamicJavaNewObjectInstance(in: _environment)
                self.init(javaThis: javaThis, environment: _environment)
            }
            public func isBigEnough(_ v: Int32) -> Bool {
                return {
                  do {
                    return try dynamicJavaMethodCall(methodName: "isBigEnough", arguments: v, resultType: Bool.self)
                  } catch {
                    if let throwable = error as? Throwable {
                  let sw = StringWriter()
                  let pw = PrintWriter(sw)
                  throwable.printStackTrace(pw)
                  fatalError("Java call threw unhandled exception: \\(error)\\n\\(sw.toString())")
                    }
                    fatalError("Java call threw unhandled exception: \\(error)")
                  }
                }()
            }

              /// The full Java class name for this Swift type.
              open class var fullJavaClassName: String {
                #if os(Android) && AndroidCoreLibraryDesugaring
                  AndroidSupport.androidDesugarClassNameConversion(for: "java.lang.Object")
                #else
                  "java.lang.Object"
                #endif
              }

              public var javaHolder: JavaObjectHolder

              public required init(javaHolder: JavaObjectHolder) {
                  self.javaHolder = javaHolder
              }
          }
        """,
      macros: Self.javaKitMacros
    )
  }

  func testJavaOptionalGenericGet() throws {
    assertMacroExpansion(
      """
        @JavaClass("java.lang.Optional")
        open class JavaOptional<T: AnyJavaObject>: JavaObject {
          @JavaMethod(typeErasedResult: "T")
          open func get() -> T!
        }
      """,
      expandedSource: """

          open class JavaOptional<T: AnyJavaObject>: JavaObject {
            open func get() -> T! {
                /* convert erased return value to T */
                let result$ = {
                  do {
                    return try dynamicJavaMethodCall(methodName: "get", resultType: /*type-erased:T*/ JavaObject?.self)
                  } catch {
                    if let throwable = error as? Throwable {
                  let sw = StringWriter()
                  let pw = PrintWriter(sw)
                  throwable.printStackTrace(pw)
                  fatalError("Java call threw unhandled exception: \\(error)\\n\\(sw.toString())")
                    }
                    fatalError("Java call threw unhandled exception: \\(error)")
                  }
                }()
                if let result$ {
                  return T(javaThis: result$.javaThis, environment: try! JavaVirtualMachine.shared().environment())
                } else {
                  return nil
                }
            }

              /// The full Java class name for this Swift type.
              open override class var fullJavaClassName: String {
                #if os(Android) && AndroidCoreLibraryDesugaring
                  AndroidSupport.androidDesugarClassNameConversion(for: "java.lang.Optional")
                #else
                  "java.lang.Optional"
                #endif
              }

              public required init(javaHolder: JavaObjectHolder) {
                  super.init(javaHolder: javaHolder)
              }
          }
        """,
      macros: Self.javaKitMacros
    )
  }

  func testJavaGenericMethodParameter() throws {
    assertMacroExpansion(
      """
      extension JavaClass {
        @JavaStaticMethod
        public func ofNullable<T: AnyJavaObject>(_ arg0: T?) -> JavaOptional<T>! 
        where ObjectType == JavaOptional<T>

        @JavaStaticMethod
        public func ofNullable2<T: AnyJavaObject>(arg0: T!, arg1: Optional<T>, arg2: T, arg3: Int)
      }
      """,
      expandedSource: #"""
        extension JavaClass {
          public func ofNullable<T: AnyJavaObject>(_ arg0: T?) -> JavaOptional<T>! 
          where ObjectType == JavaOptional<T> {
              let arg0$erased = arg0.map {
                  JavaObject(javaHolder: $0.javaHolder)
              }
              return {
                do {
                  return try dynamicJavaStaticMethodCall(methodName: "ofNullable", arguments: arg0$erased, resultType: JavaOptional<T>?.self)
                } catch {
                  if let throwable = error as? Throwable {
                let sw = StringWriter()
                let pw = PrintWriter(sw)
                throwable.printStackTrace(pw)
                fatalError("Java call threw unhandled exception: \(error)\n\(sw.toString())")
                  }
                  fatalError("Java call threw unhandled exception: \(error)")
                }
              }()
          }
          public func ofNullable2<T: AnyJavaObject>(arg0: T!, arg1: Optional<T>, arg2: T, arg3: Int) {
              let arg0$erased = arg0.map {
                  JavaObject(javaHolder: $0.javaHolder)
              }
              let arg1$erased = arg1.map {
                  JavaObject(javaHolder: $0.javaHolder)
              }
              let arg2$erased = JavaObject(javaHolder: arg2.javaHolder)
              return {
                do {
                  return try dynamicJavaStaticMethodCall(methodName: "ofNullable2", arguments: arg0$erased, arg1$erased, arg2$erased, arg3)
                } catch {
                  if let throwable = error as? Throwable {
                let sw = StringWriter()
                let pw = PrintWriter(sw)
                throwable.printStackTrace(pw)
                fatalError("Java call threw unhandled exception: \(error)\n\(sw.toString())")
                  }
                  fatalError("Java call threw unhandled exception: \(error)")
                }
              }()
          }
        }
        """#,
      macros: Self.javaKitMacros
    )
  }

  func testJavaRecord() throws {
    assertMacroExpansion(
      """
        @JavaRecord("com.example.Point")
        open class Point: JavaObject {
          @JavaMethod
          @_nonoverride public convenience init(_ x: Int32, _ y: Int32, environment: JNIEnvironment? = nil)

          @JavaMethod
          open func x() -> Int32
        }
      """,
      expandedSource: """

          open class Point: JavaObject {
            @_nonoverride public convenience init(_ x: Int32, _ y: Int32, environment: JNIEnvironment? = nil) {
                let _environment = if let environment {
                    environment
                } else {
                    try! JavaVirtualMachine.shared().environment()
                }
                let javaThis = try! Self.dynamicJavaNewObjectInstance(in: _environment, arguments: x.self, y.self)
                self.init(javaThis: javaThis, environment: _environment)
            }
            open func x() -> Int32 {
                return {
                  do {
                    return try dynamicJavaMethodCall(methodName: "x", resultType: Int32.self)
                  } catch {
                    if let throwable = error as? Throwable {
                  let sw = StringWriter()
                  let pw = PrintWriter(sw)
                  throwable.printStackTrace(pw)
                  fatalError("Java call threw unhandled exception: \\(error)\\n\\(sw.toString())")
                    }
                    fatalError("Java call threw unhandled exception: \\(error)")
                  }
                }()
            }

              /// The full Java class name for this Swift type.
              open override class var fullJavaClassName: String {
                #if os(Android) && AndroidCoreLibraryDesugaring
                  AndroidSupport.androidDesugarClassNameConversion(for: "com.example.Point")
                #else
                  "com.example.Point"
                #endif
              }

              public required init(javaHolder: JavaObjectHolder) {
                  super.init(javaHolder: javaHolder)
              }
          }
        """,
      macros: Self.javaKitMacros
    )
  }

  func testJavaClassSealedWithoutPermits() throws {
    assertMacroExpansion(
      """
      @JavaClass(.sealed, "com.example.Foo")
      open class Foo: JavaObject {
      }
      """,
      expectedChunks: [],
      notExpectedChunks: [
        "public func as"
      ]
    )
  }

  func testJavaInterfaceOnEnum() throws {
    // A Java `sealed interface` is wrapped as a Swift enum. The macro emits
    // only `fullJavaClassName` for enum declarations -- the case list,
    // `javaHolder`, and `init(javaHolder:)` are supplied by the generator
    // (which has the permitted-subclass list). The extension macro still
    // adds `AnyJavaObject` conformance on top.
    assertMacroExpansion(
      """
      @JavaInterface(.sealed, "com.example.Op")
      public enum Op {
        case add(Add)
        case mul(Mul)
      }
      """,
      expectedChunks: [
        "public static var fullJavaClassName: String",
        #""com.example.Op""#,
      ],
      notExpectedChunks: [
        // Enum branch must not synthesize a stored `javaHolder` (illegal
        // on enums) or the struct-shaped `init(javaHolder:)`.
        "public var javaHolder: JavaObjectHolder",
        "public required init(javaHolder: JavaObjectHolder)",
        "public typealias JavaSuperclass",
      ]
    )
  }

  func testJavaGenericClassGenericMethodParameter() throws {
    assertMacroExpansion(
      """
      @JavaClass("java.util.ArrayList")
      open class ArrayList<ArrayList_E: AnyJavaObject>: JavaObject {
        public typealias E = ArrayList_E 
        @JavaMethod
        open func add(_ arg0: E?) -> Bool
      }
      """,
      expandedSource: #"""
        open class ArrayList<ArrayList_E: AnyJavaObject>: JavaObject {
          public typealias E = ArrayList_E 
          open func add(_ arg0: E?) -> Bool {
              let arg0$erased = arg0.map {
                  JavaObject(javaHolder: $0.javaHolder)
              }
              return {
                do {
                  return try dynamicJavaMethodCall(methodName: "add", arguments: arg0$erased, resultType: Bool.self)
                } catch {
                  if let throwable = error as? Throwable {
                let sw = StringWriter()
                let pw = PrintWriter(sw)
                throwable.printStackTrace(pw)
                fatalError("Java call threw unhandled exception: \(error)\n\(sw.toString())")
                  }
                  fatalError("Java call threw unhandled exception: \(error)")
                }
              }()
          }

            /// The full Java class name for this Swift type.
            open override class var fullJavaClassName: String {
              #if os(Android) && AndroidCoreLibraryDesugaring
                AndroidSupport.androidDesugarClassNameConversion(for: "java.util.ArrayList")
              #else
                "java.util.ArrayList"
              #endif
            }

            public required init(javaHolder: JavaObjectHolder) {
                super.init(javaHolder: javaHolder)
            }
        }
        """#,
      macros: Self.javaKitMacros
    )
  }
}

private func assertMacroExpansion(
  _ source: String,
  expectedChunks: [String],
  notExpectedChunks: [String] = [],
  file: StaticString = #fileID,
  line: UInt = #line
) {
  let expanded = expandMacros(in: source)
  let expandedCollapsed = expanded.replacing(" ", with: "")
  for chunk in expectedChunks {
    let chunkCollapsed = chunk.replacing(" ", with: "")
    XCTAssertTrue(
      expandedCollapsed.contains(chunkCollapsed),
      "Expected chunk:\n\(chunk)\n\nnot found in expanded source:\n\(expanded)",
      file: file,
      line: line
    )
  }
  for chunk in notExpectedChunks {
    let chunkCollapsed = chunk.replacing(" ", with: "")
    XCTAssertFalse(
      expandedCollapsed.contains(chunkCollapsed),
      "Unexpected chunk:\n\(chunk)\n\nfound in expanded source:\n\(expanded)",
      file: file,
      line: line
    )
  }
}

private func expandMacros(in source: String) -> String {
  let origSourceFile = Parser.parse(source: source)
  let context = BasicMacroExpansionContext(
    sourceFiles: [origSourceFile: .init(moduleName: "TestModule", fullFilePath: "test.swift")]
  )
  let expanded = origSourceFile.expand(
    macros: JavaKitMacroTests.javaKitMacros,
    contextGenerator: { syntax in
      BasicMacroExpansionContext(sharingWith: context, lexicalContext: syntax.allMacroLexicalContexts())
    },
    indentationWidth: .spaces(2)
  )
  return expanded.description
}
