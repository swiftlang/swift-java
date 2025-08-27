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
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

class JavaKitMacroTests: XCTestCase {
  static let javaKitMacros: [String: any Macro.Type] = [
    "JavaClass": JavaClassMacro.self,
    "JavaMethod": JavaMethodMacro.self,
    "JavaField": JavaFieldMacro.self,
    "JavaStaticField": JavaFieldMacro.self
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
                "org.swift.example.HelloWorld"
            }
      
            public required init(javaHolder: JavaObjectHolder) {
                super.init(javaHolder: javaHolder)
            }
        }
      """,
      diagnostics: [DiagnosticSpec(message: "Cannot use @JavaStaticField outside of a JavaClass instance", line: 3, column: 5)],
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
    assertMacroExpansion("""
        @JavaClass("org.swift.example.HelloWorld")
        public struct HelloWorld {
          @JavaMethod
          public init(environment: JNIEnvironment? = nil)
      
          @JavaMethod
          public init(_ value: Int32, environment: JNIEnvironment? = nil)

          @JavaMethod
          public func isBigEnough(_: Int32) -> Bool

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
          public func isBigEnough(_: Int32) -> Bool {
              return try! dynamicJavaMethodCall(methodName: "isBigEnough", resultType: Bool.self)
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
                "org.swift.example.HelloWorld"
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
    assertMacroExpansion("""
        @JavaClass("org.swift.example.HelloWorld")
        public class HelloWorld: OtherJavaType {
          @JavaMethod
          public init(environment: JNIEnvironment? = nil)

          @JavaMethod
          public init(_ value: Int32, environment: JNIEnvironment? = nil)

          @JavaMethod
          public func isBigEnough(_: Int32) -> Bool

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
          public func isBigEnough(_: Int32) -> Bool {
              return try! dynamicJavaMethodCall(methodName: "isBigEnough", resultType: Bool.self)
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
                "org.swift.example.HelloWorld"
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
    assertMacroExpansion("""
        @JavaClass("java.lang.Object")
        public class JavaObject {
          @JavaMethod
          public init(environment: JNIEnvironment? = nil)

          @JavaMethod
          public func isBigEnough(_: Int32) -> Bool
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
          public func isBigEnough(_: Int32) -> Bool {
              return try! dynamicJavaMethodCall(methodName: "isBigEnough", resultType: Bool.self)
          }

            /// The full Java class name for this Swift type.
            open class var fullJavaClassName: String {
                "java.lang.Object"
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
}

