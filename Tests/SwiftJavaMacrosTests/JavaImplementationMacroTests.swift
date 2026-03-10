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

class JavaImplementationMacroTests: XCTestCase {
  static let javaImplementationMacros: [String: any Macro.Type] = [
    "JavaImplementation": JavaImplementationMacro.self,
    "JavaMethod": JavaMethodMacro.self,
  ]

  func testJNIIdentifierEscaping() throws {
    assertMacroExpansion(
      """
      @JavaImplementation("org.swift.example.Hello_World")
      extension HelloWorld {
        @JavaMethod
        func test_method() -> Int32 {
          return 42
        }
      }
      """,
      expandedSource: """

        extension HelloWorld {
          func test_method() -> Int32 {
              return 42
          }
        }

        @_cdecl("Java_org_swift_example_Hello_1World_test_1method")
        func __macro_local_11test_methodfMu_(environment: UnsafeMutablePointer<JNIEnv?>!, thisObj: jobject) -> Int32.JNIType {
          let obj = HelloWorld(javaThis: thisObj, environment: environment!)
          return obj.test_method()
          .getJNIValue(in: environment)
        }
        """,
      macros: Self.javaImplementationMacros
    )
  }

  func testJNIIdentifierEscapingWithDots() throws {
    assertMacroExpansion(
      """
      @JavaImplementation("com.example.test.MyClass")
      extension MyClass {
        @JavaMethod
        func simpleMethod() -> Int32 {
          return 1
        }
      }
      """,
      expandedSource: """

        extension MyClass {
          func simpleMethod() -> Int32 {
              return 1
          }
        }

        @_cdecl("Java_com_example_test_MyClass_simpleMethod")
        func __macro_local_12simpleMethodfMu_(environment: UnsafeMutablePointer<JNIEnv?>!, thisObj: jobject) -> Int32.JNIType {
          let obj = MyClass(javaThis: thisObj, environment: environment!)
          return obj.simpleMethod()
          .getJNIValue(in: environment)
        }
        """,
      macros: Self.javaImplementationMacros
    )
  }

  func testJNIIdentifierEscapingStaticMethod() throws {
    assertMacroExpansion(
      """
      @JavaImplementation("org.example.Utils")
      extension Utils {
        @JavaMethod
        static func static_helper(environment: JNIEnvironment) -> String {
          return "hello"
        }
      }
      """,
      expandedSource: """

        extension Utils {
          static func static_helper(environment: JNIEnvironment) -> String {
              return "hello"
          }
        }

        @_cdecl("Java_org_example_Utils_static_1helper")
        func __macro_local_13static_helperfMu_(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> String.JNIType {
          return Utils.static_helper(environment: environment)
          .getJNIValue(in: environment)
        }
        """,
      macros: Self.javaImplementationMacros
    )
  }

  func testJNIIdentifierEscapingMultipleMethods() throws {
    assertMacroExpansion(
      """
      @JavaImplementation("test.Class_With_Underscores")
      extension ClassWithUnderscores {
        @JavaMethod
        func method_one() -> Int32 {
          return 1
        }

        @JavaMethod
        func method_two() -> Int32 {
          return 2
        }
      }
      """,
      expandedSource: """

        extension ClassWithUnderscores {
          func method_one() -> Int32 {
              return 1
          }
          func method_two() -> Int32 {
              return 2
          }
        }

        @_cdecl("Java_test_Class_1With_1Underscores_method_1one")
        func __macro_local_10method_onefMu_(environment: UnsafeMutablePointer<JNIEnv?>!, thisObj: jobject) -> Int32.JNIType {
          let obj = ClassWithUnderscores(javaThis: thisObj, environment: environment!)
          return obj.method_one()
          .getJNIValue(in: environment)
        }

        @_cdecl("Java_test_Class_1With_1Underscores_method_1two")
        func __macro_local_10method_twofMu_(environment: UnsafeMutablePointer<JNIEnv?>!, thisObj: jobject) -> Int32.JNIType {
          let obj = ClassWithUnderscores(javaThis: thisObj, environment: environment!)
          return obj.method_two()
          .getJNIValue(in: environment)
        }
        """,
      macros: Self.javaImplementationMacros
    )
  }

  func testJNIIdentifierEscapingVoidReturn() throws {
    assertMacroExpansion(
      """
      @JavaImplementation("org.example.Processor")
      extension Processor {
        @JavaMethod
        func process_data() {
          // do nothing
        }
      }
      """,
      expandedSource: """

        extension Processor {
          func process_data() {
            // do nothing
          }
        }

        @_cdecl("Java_org_example_Processor_process_1data")
        func __macro_local_12process_datafMu_(environment: UnsafeMutablePointer<JNIEnv?>!, thisObj: jobject) {
          let obj = Processor(javaThis: thisObj, environment: environment!)
          return obj.process_data()
        }
        """,
      macros: Self.javaImplementationMacros
    )
  }

}
