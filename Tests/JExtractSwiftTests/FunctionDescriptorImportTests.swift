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

import JExtractSwift
import Testing

@Suite
final class FunctionDescriptorTests {
  let interfaceFile =
    """
    // swift-interface-format-version: 1.0
    // swift-compiler-version: Apple Swift version 6.0 effective-5.10 (swiftlang-6.0.0.7.6 clang-1600.0.24.1)
    // swift-module-flags: -target arm64-apple-macosx15.0 -enable-objc-interop -enable-library-evolution -module-name MySwiftLibrary
    import Darwin.C
    import Darwin
    import Swift
    import _Concurrency
    import _StringProcessing
    import _SwiftConcurrencyShims

    // MANGLED NAME: $s14MySwiftLibrary10helloWorldyyF
    public func helloWorld()
    // MANGLED NAME: $s14MySwiftLibrary13globalTakeInt1iySi_tF
    public func globalTakeInt(i: Swift.Int)

    // MANGLED NAME: $s14MySwiftLibrary23globalTakeLongIntString1l3i321sys5Int64V_s5Int32VSStF
    public func globalTakeLongInt(l: Int64, i32: Int32)

    // MANGLED NAME: $s14MySwiftLibrary7echoInt1iS2i_tFs
    public func echoInt(i: Int) -> Int

    // MANGLED NAME: $s14MySwiftLibrary0aB5ClassCMa
    public class MySwiftClass {
      // MANGLED NAME: $s14MySwiftLibrary0aB5ClassC3len3capACSi_SitcfC
      public init(len: Swift.Int, cap: Swift.Int)
      @objc deinit
    }
    """

  func functionDescriptorTest(
    _ methodIdentifier: String,
    javaPackage: String = "com.example.swift",
    swiftModuleName: String = "SwiftModule",
    logLevel: Logger.Level = .trace,
    body: (String) async throws -> ()
  ) async throws {
    let st = Swift2JavaTranslator(
      javaPackage: javaPackage,
      swiftModuleName: swiftModuleName
    )
    st.log.logLevel = logLevel

    try await st.analyze(swiftInterfacePath: "/fake/Sample.swiftinterface", text: interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.baseIdentifier == methodIdentifier
    }!

    let output = CodePrinter.toString { printer in
      st.printFunctionDescriptorValue(&printer, funcDecl)
    }

    try await body(output)
  }

  @Test
  func FunctionDescriptor_globalTakeInt() async throws {
    try await functionDescriptorTest("globalTakeInt") { output in
      assertOutput(
        output,
        expected:
          """
          public static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            SWIFT_INT
          );
          """
      )
    }
  }

  @Test
  func FunctionDescriptor_globalTakeLongIntString() async throws {
    try await functionDescriptorTest("globalTakeLongInt") { output in
      assertOutput(
        output,
        expected:
          """
          public static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            SWIFT_INT64,
            SWIFT_INT32
          );
          """
      )
    }
  }

  @Test
  func FunctionDescriptor_echoInt() async throws {
    try await functionDescriptorTest("echoInt") { output in
      assertOutput(
        output,
        expected:
          """
          public static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SWIFT_INT,
            SWIFT_INT
          );
          """
      )
    }
  }

}
