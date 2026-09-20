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

import SwiftJavaConfigurationShared
import Testing

@testable import JExtractSwiftLib

@Suite
struct JavaPackageValidationTests {
  @Test func rejectsNil() {
    #expect(throws: JavaPackageError.missing) {
      try validateJavaPackage(nil)
    }
  }

  @Test func rejectsEmpty() {
    #expect(throws: JavaPackageError.missing) {
      try validateJavaPackage("")
    }
  }

  @Test func rejectsWhitespaceOnly() {
    #expect(throws: JavaPackageError.missing) {
      try validateJavaPackage("   ")
    }
  }

  @Test func rejectsSurroundingWhitespace() {
    #expect(throws: JavaPackageError.missing) {
      try validateJavaPackage(" com.example.foo ")
    }
  }

  @Test func rejectsEmptySegment() {
    #expect(throws: JavaPackageError.emptySegment("com..foo")) {
      try validateJavaPackage("com..foo")
    }
  }

  @Test func rejectsLeadingDot() {
    #expect(throws: JavaPackageError.emptySegment(".foo")) {
      try validateJavaPackage(".foo")
    }
  }

  @Test func rejectsTrailingDot() {
    #expect(throws: JavaPackageError.emptySegment("foo.")) {
      try validateJavaPackage("foo.")
    }
  }

  @Test func acceptsNonEmptyPackageUnchanged() throws {
    #expect(try validateJavaPackage("com.example.foo") == "com.example.foo")
  }

  @Test func runThrowsOnNilJavaPackage() {
    var config = Configuration()
    config.swiftModule = "MySwift"
    #expect(throws: JavaPackageError.missing) {
      try SwiftToJava(config: config, dependencyConfigs: []).run()
    }
  }

  @Test func runThrowsOnEmptyJavaPackage() {
    var config = Configuration()
    config.swiftModule = "MySwift"
    config.javaPackage = ""
    #expect(throws: JavaPackageError.missing) {
      try SwiftToJava(config: config, dependencyConfigs: []).run()
    }
  }
}
