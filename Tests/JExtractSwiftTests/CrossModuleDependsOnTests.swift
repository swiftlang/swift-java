//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
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

/// Covers swift-java issue #715 / #746: when TargetA's API references a type
/// declared in TargetB, jextract should be able to resolve TargetB's type via
/// `--depends-on` (no hand-written `importedModuleStubs` required) and emit the
/// cross-module Java type using TargetB's package.
@Suite("Cross-module --depends-on resolution")
struct CrossModuleDependsOnTests {

  // ==== ----------------------------------------------------------------------
  // MARK: Top-level type from a dependency module

  @Test("JNI: top-level type from dependency module is resolved and printed with its Java package")
  func jni_topLevelType_resolvedAndQualified() throws {
    let dependencySource = """
      public struct DependencyPayload {
        public let value: Int32
        public init(value: Int32) {
          self.value = value
        }
      }
      """
    let primarySource = """
      import DependencyLib

      public func consumePayload(_ p: DependencyPayload) -> Int32 {
        return p.value
      }
      """

    try assertOutput(
      input: primarySource,
      .jni,
      .java,
      swiftModuleName: "PrimaryLib",
      dependencySwiftSources: ["DependencyLib": dependencySource],
      moduleJavaPackages: ["DependencyLib": "com.example.dep"],
      expectedChunks: [
        "consumePayload(com.example.dep.DependencyPayload p)"
      ],
    )
  }

  @Test("JNI: without dependency sources the function is dropped from the bindings")
  func jni_topLevelType_droppedWithoutDependency() throws {
    let primarySource = """
      import DependencyLib

      public func consumePayload(_ p: DependencyPayload) -> Int32 {
        return p.value
      }
      """

    try assertOutput(
      input: primarySource,
      .jni,
      .java,
      swiftModuleName: "PrimaryLib",
      // Intentionally no dependencySwiftSources — simulates calling jextract
      // without --depends-on for DependencyLib. The function should be skipped.
      expectedChunks: [],
      notExpectedChunks: ["consumePayload"],
    )
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Multiple dependency modules

  @Test("JNI: parameters from two distinct dependency modules both resolve")
  func jni_twoDependentModules() throws {
    let depA = """
      public struct InputBlob {
        public let raw: Int64
        public init(raw: Int64) { self.raw = raw }
      }
      """
    let depB = """
      public struct OutputBlob {
        public let raw: Int64
        public init(raw: Int64) { self.raw = raw }
      }
      """
    let primarySource = """
      import DepA
      import DepB

      public func transform(_ input: InputBlob) -> OutputBlob {
        return OutputBlob(raw: input.raw)
      }
      """

    try assertOutput(
      input: primarySource,
      .jni,
      .java,
      swiftModuleName: "PrimaryLib",
      dependencySwiftSources: [
        "DepA": depA,
        "DepB": depB,
      ],
      moduleJavaPackages: [
        "DepA": "com.example.depa",
        "DepB": "com.example.depb",
      ],
      expectedChunks: [
        "public static com.example.depb.OutputBlob transform(com.example.depa.InputBlob input,"
      ],
    )
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Nested types from a dependency module
  //
  // Exercises the case where a primary module's API references a nested type
  // (e.g. `Outer.Inner`) declared inside an enum in another SwiftPM target.
  // Without sourcing the dependency module's real declarations the only prior
  // workaround was hand-writing an empty `public enum Outer {}` stub.

  @Test("JNI: nested type inside a dependency-module namespace enum is resolved")
  func jni_nestedTypeInDependentModule() throws {
    let dependencySource = """
      public enum Outer {
        public struct Inner {
          public let value: Int32
          public init(value: Int32) {
            self.value = value
          }
        }
      }
      """
    let primarySource = """
      import DependencyLib

      public func consumeInner(_ inner: Outer.Inner) -> Int32 {
        return inner.value
      }
      """

    try assertOutput(
      input: primarySource,
      .jni,
      .java,
      swiftModuleName: "PrimaryLib",
      dependencySwiftSources: ["DependencyLib": dependencySource],
      moduleJavaPackages: ["DependencyLib": "com.example.dep"],
      expectedChunks: [
        "consumeInner(com.example.dep.Outer.Inner inner)"
      ],
    )
  }
}
