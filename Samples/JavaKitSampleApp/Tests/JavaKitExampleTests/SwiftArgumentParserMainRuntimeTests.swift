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

import JavaKitExample
import SwiftJava
import Testing

/// Exercises a Java `static native` entry point whose implementation is written
/// in Swift and parses its arguments with swift-argument-parser.
@Suite
struct SwiftArgumentParserMainRuntimeTests {

  let jvm = try JavaKitSampleJVM.shared

  @Test
  func defaultArguments() throws {
    let mainClass = try JavaClass<SwiftArgumentParserMain>(environment: jvm.environment())
    #expect(mainClass.runSwiftMain([]) == "Hello, world!")
  }

  @Test
  func positionalArgument() throws {
    let mainClass = try JavaClass<SwiftArgumentParserMain>(environment: jvm.environment())
    #expect(mainClass.runSwiftMain(["Swift"]) == "Hello, Swift!")
  }

  @Test
  func verboseFlag() throws {
    let mainClass = try JavaClass<SwiftArgumentParserMain>(environment: jvm.environment())
    #expect(mainClass.runSwiftMain(["--verbose", "Swift"]) == "Hello, Swift! (verbose)")
  }

  @Test
  func invalidArgumentsReportParserError() throws {
    let mainClass = try JavaClass<SwiftArgumentParserMain>(environment: jvm.environment())
    let output = mainClass.runSwiftMain(["--nope"])
    #expect(output.contains("--nope"))
  }
}
