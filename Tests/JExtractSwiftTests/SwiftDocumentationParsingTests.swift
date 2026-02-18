//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

struct SwiftDocumentationParsingTests {
  @Test(
    "Simple Swift func documentation",
    arguments: [
      (
        JExtractGenerationMode.jni,
        [
          """
          /**
           * Simple summary
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f()
           * }
           */
          public static void f() {
          """
        ]
      ),
      (
        JExtractGenerationMode.ffm,
        [
          """
          /**
           * Simple summary
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f()
           * }
           */
          public static void f() {
          """
        ]
      ),
    ]
  )
  func simple(mode: JExtractGenerationMode, expectedJavaChunks: [String]) throws {
    let text =
      """
      /// Simple summary
      public func f() {}
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )
  }

  @Test(
    "Swift file with lots of newlines",
    arguments: [
      (
        JExtractGenerationMode.jni,
        [
          """
          /**
           * Downcall to Swift:
           * {@snippet lang=swift :
           * public func f()
           * }
           */
          public static void f() {
          """,
          """
          /**
           * Simple summary
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func g()
           * }
           */
          public static void g() {
          """,
        ]
      ),
      (
        JExtractGenerationMode.ffm,
        [
          """
          /**
           * Downcall to Swift:
           * {@snippet lang=swift :
           * public func f()
           * }
           */
          public static void f() {
          """,
          """
          /**
           * Simple summary
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func g()
           * }
           */
          public static void g() {
          """,
        ]
      ),
    ]
  )
  func swiftFileWithNewlines(mode: JExtractGenerationMode, expectedJavaChunks: [String]) throws {
    let text =
      """
      /// Random comment




      public func f() {}

      /// Random comment 2

      /// Simple summary
      public func g() {}
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )
  }

  @Test(
    "Swift arena parameter",
    arguments: [
      (
        JExtractGenerationMode.jni,
        [
          """
          /**
           * Simple summary
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f() -> MyClass
           * }
           *
           * @param swiftArena$ the arena that the the returned object will be attached to
           */
          public static MyClass f(SwiftArena swiftArena$) {
          """
        ]
      ),
      (
        JExtractGenerationMode.ffm,
        [
          """
          /**
           * Simple summary
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f() -> MyClass
           * }
           *
           * @param swiftArena$ the arena that will manage the lifetime and allocation of Swift objects
           */
          public static MyClass f(AllocatingSwiftArena swiftArena$)
          """
        ]
      ),
    ]
  )
  func swiftArenaParam(mode: JExtractGenerationMode, expectedJavaChunks: [String]) throws {
    let text =
      """
      public class MyClass {}

      /// Simple summary
      public func f() -> MyClass {}
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )
  }

  @Test(
    "Full Swift func docs with individual params",
    arguments: [
      (
        JExtractGenerationMode.jni,
        [
          """
          /**
           * Simple summary
           *
           * <p>Some information about this function
           * that will span multiple lines
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f(arg0: String, arg1: String)
           * }
           *
           * @param arg0 Description about arg0
           * @param arg1 Description about arg1
           * @return return value
           */
          public static void f(java.lang.String arg0, java.lang.String arg1) {
          """
        ]
      ),
      (
        JExtractGenerationMode.ffm,
        [
          """
          /**
           * Simple summary
           *
           * <p>Some information about this function
           * that will span multiple lines
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f(arg0: String, arg1: String)
           * }
           *
           * @param arg0 Description about arg0
           * @param arg1 Description about arg1
           * @return return value
           */
          public static void f(java.lang.String arg0, java.lang.String arg1) {
          """
        ]
      ),
    ]
  )
  func full_individualParams(mode: JExtractGenerationMode, expectedJavaChunks: [String]) throws {
    let text =
      """
      /// Simple summary
      /// 
      /// Some information about this function
      /// that will span multiple lines
      /// 
      /// - Parameter arg0: Description about arg0
      /// - Parameter arg1: Description about arg1
      /// 
      /// - Returns: return value
      public func f(arg0: String, arg1: String) {}
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )
  }

  @Test(
    "Full Swift func docs with grouped params",
    arguments: [
      (
        JExtractGenerationMode.jni,
        [
          """
          /**
           * Simple summary
           *
           * <p>Some information about this function
           * that will span multiple lines
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f(arg0: String, arg1: String)
           * }
           *
           * @param arg0 Description about arg0
           * @param arg1 Description about arg1
           * @return return value
           */
          public static void f(java.lang.String arg0, java.lang.String arg1) {
          """
        ]
      ),
      (
        JExtractGenerationMode.ffm,
        [
          """
          /**
           * Simple summary
           *
           * <p>Some information about this function
           * that will span multiple lines
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f(arg0: String, arg1: String)
           * }
           *
           * @param arg0 Description about arg0
           * @param arg1 Description about arg1
           * @return return value
           */
          public static void f(java.lang.String arg0, java.lang.String arg1) {
          """
        ]
      ),
    ]
  )
  func full_groupedParams(mode: JExtractGenerationMode, expectedJavaChunks: [String]) throws {
    let text =
      """
      /// Simple summary
      /// 
      /// Some information about this function
      /// that will span multiple lines
      /// 
      /// - Parameters:
      ///   - arg0: Description about arg0
      ///   - arg1: Description about arg1
      /// 
      /// - Returns: return value
      public func f(arg0: String, arg1: String) {}
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )
  }

  @Test(
    "Complex Swift func docs",
    arguments: [
      (
        JExtractGenerationMode.jni,
        [
          """
          /**
           * Simple summary, that we have broken
           * across multiple lines
           * 
           * <p>Some information about this function
           * that will span multiple lines
           * 
           * <p>Some more disucssion...
           * 
           * <p>And more...
           * 
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f(arg0: String, arg1: String)
           * }
           * 
           * @param arg0 Description about arg0
           * that spans multiple lines
           * @param arg1 Description about arg1
           * that spans multiple lines
           * and even more?
           * @return return value
           * across multiple lines
           */
          public static void f(java.lang.String arg0, java.lang.String arg1) {
          """
        ]
      ),
      (
        JExtractGenerationMode.ffm,
        [
          """
          /**
           * Simple summary, that we have broken
           * across multiple lines
           * 
           * <p>Some information about this function
           * that will span multiple lines
           * 
           * <p>Some more disucssion...
           * 
           * <p>And more...
           * 
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f(arg0: String, arg1: String)
           * }
           * 
           * @param arg0 Description about arg0
           * that spans multiple lines
           * @param arg1 Description about arg1
           * that spans multiple lines
           * and even more?
           * @return return value
           * across multiple lines
           */
          public static void f(java.lang.String arg0, java.lang.String arg1) {
          """
        ]
      ),
    ]
  )
  func complex(mode: JExtractGenerationMode, expectedJavaChunks: [String]) throws {
    let text =
      """
      /// Simple summary, that we have broken
      /// across multiple lines
      /// 
      /// Some information about this function
      /// that will span multiple lines
      ///
      /// Some more disucssion...
      /// 
      /// - Parameters:
      ///   - arg0: Description about arg0
      ///           that spans multiple lines
      ///   - arg1: Description about arg1
      ///           that spans multiple lines
      ///           and even more?
      ///
      /// And more...
      /// 
      /// - Returns: return value
      ///            across multiple lines
      public func f(arg0: String, arg1: String) {}
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )
  }

  @Test(
    "Random order docs",
    arguments: [
      (
        JExtractGenerationMode.jni,
        [
          """
          /**
           * <p>Discussion?
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f(arg0: String, arg1: String)
           * }
           *
           * @param arg0 this is arg0
           * @param arg1 this is arg1
           * @return return value
           */
          public static void f(java.lang.String arg0, java.lang.String arg1) {
          """
        ]
      ),
      (
        JExtractGenerationMode.ffm,
        [
          """
          /**
           * <p>Discussion?
           *
           * <p>Downcall to Swift:
           * {@snippet lang=swift :
           * public func f(arg0: String, arg1: String)
           * }
           *
           * @param arg0 this is arg0
           * @param arg1 this is arg1
           * @return return value
           */
          public static void f(java.lang.String arg0, java.lang.String arg1) {
          """
        ]
      ),
    ]
  )
  func randomOrder(mode: JExtractGenerationMode, expectedJavaChunks: [String]) throws {
    let text =
      """
      /// - Parameter arg0: this is arg0
      /// - Returns: return value
      /// - Parameter arg1: this is arg1
      ///
      /// Discussion? 
      public func f(arg0: String, arg1: String) {}
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )
  }
}
