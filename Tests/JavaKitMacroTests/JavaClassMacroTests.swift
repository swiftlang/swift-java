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

import JavaKitMacros
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

class JavaKitMacroTests: XCTestCase {
  static let javaKitMacros: [String: any Macro.Type] = [
    "JavaClass": JavaClassMacro.self,
    "JavaMethod": JavaMethodMacro.self,
    "JavaField": JavaFieldMacro.self
  ]

  func testJavaClass() throws {
    assertMacroExpansion("""
        @JavaClass("org.swift.example.HelloWorld")
        public struct HelloWorld {
          @JavaMethod
          public init(_ value: Int32, environment: JNIEnvironment) 

          @JavaMethod
          public func isBigEnough(_: Int32) -> Bool

          @JavaField
          public var myField: Int64
        }
      """,
      expandedSource: """

        public struct HelloWorld {
          public init(_ value: Int32, environment: JNIEnvironment)  {
              self = try! Self.dynamicJavaNewObject(in: environment, arguments: value.self)
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
      
            /// The full Java class name for this Swift type.
            public static var fullJavaClassName: String {
                "org.swift.example.HelloWorld"
            }

            public typealias JavaSuperclass = JavaObject

            public var javaHolder: JavaObjectHolder

            public var javaThis: jobject {
              javaHolder.object!
            }

            public var javaEnvironment: JNIEnvironment {
              javaHolder.environment
            }

            public init(javaHolder: JavaObjectHolder) {
                self.javaHolder = javaHolder
            }

            /// It's not checking anything.
            public func `as`<OtherClass: AnyJavaObject>(_: OtherClass.Type) -> OtherClass {
                return OtherClass(javaHolder: javaHolder)
            }
        }
      """,
      macros: Self.javaKitMacros
    )
  }
}

