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

    public func helloWorld()
    public func globalTakeInt(i: Swift.Int)

    public func globalTakeLongInt(l: Int64, i32: Int32)

    public func echoInt(i: Int) -> Int

    public class MySwiftClass {
      public init(len: Swift.Int, cap: Swift.Int)
      @objc deinit

      public var counter: Int32
    }
    """

  @Test
  func FunctionDescriptor_globalTakeInt() throws {
    try functionDescriptorTest("globalTakeInt") { output in
      assertOutput(
        output,
        expected:
          """
          public static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* i: */SwiftValueLayout.SWIFT_INT
          );
          """
      )
    }
  }

  @Test
  func FunctionDescriptor_globalTakeLongIntString() throws {
    try functionDescriptorTest("globalTakeLongInt") { output in
      assertOutput(
        output,
        expected:
          """
          public static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* l: */SwiftValueLayout.SWIFT_INT64,
            /* i32: */SwiftValueLayout.SWIFT_INT32
          );
          """
      )
    }
  }

  @Test
  func FunctionDescriptor_echoInt() throws {
    try functionDescriptorTest("echoInt") { output in
      assertOutput(
        output,
        expected:
          """
          public static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_INT,
            /* i: */SwiftValueLayout.SWIFT_INT
          );
          """
      )
    }
  }

  @Test
  func FunctionDescriptor_class_counter_get() throws {
    try variableAccessorDescriptorTest("counter", .getter) { output in
      assertOutput(
        output,
        expected:
          """
          public static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_INT32,
            /* self: */SwiftValueLayout.SWIFT_POINTER
          );
          """
      )
    }
  }
  @Test
  func FunctionDescriptor_class_counter_set() throws {
    try variableAccessorDescriptorTest("counter", .setter) { output in
      assertOutput(
        output,
        expected:
          """
          public static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* newValue: */SwiftValueLayout.SWIFT_INT32,
            /* self: */SwiftValueLayout.SWIFT_POINTER
          );
          """
      )
    }
  }

}

extension FunctionDescriptorTests {

  func functionDescriptorTest(
    _ methodIdentifier: String,
    javaPackage: String = "com.example.swift",
    swiftModuleName: String = "SwiftModule",
    logLevel: Logger.Level = .trace,
    body: (String) throws -> Void
  ) throws {
    let st = Swift2JavaTranslator(
      javaPackage: javaPackage,
      swiftModuleName: swiftModuleName
    )
    st.log.logLevel = logLevel

    try st.analyze(file: "/fake/Sample.swiftinterface", text: interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == methodIdentifier
    }!

    let thunkName = st.thunkNameRegistry.functionThunkName(decl: funcDecl)
    let cFunc = funcDecl.cFunctionDecl(cName: thunkName)
    let output = CodePrinter.toString { printer in
      st.printFunctionDescriptorValue(&printer, cFunc)
    }

    try body(output)
  }

  func variableAccessorDescriptorTest(
    _ identifier: String,
    _ accessorKind: SwiftAPIKind,
    javaPackage: String = "com.example.swift",
    swiftModuleName: String = "SwiftModule",
    logLevel: Logger.Level = .trace,
    body: (String) throws -> Void
  ) throws {
    let st = Swift2JavaTranslator(
      javaPackage: javaPackage,
      swiftModuleName: swiftModuleName
    )
    st.log.logLevel = logLevel

    try st.analyze(file: "/fake/Sample.swiftinterface", text: interfaceFile)

    let accessorDecl: ImportedFunc? =
      st.importedTypes.values.compactMap {
        $0.variables.first {
          $0.name == identifier && $0.kind == accessorKind
        }
      }.first
    guard let accessorDecl else {
      fatalError("Cannot find descriptor of: \(identifier)")
    }

    let thunkName = st.thunkNameRegistry.functionThunkName(decl: accessorDecl)
    let cFunc = accessorDecl.cFunctionDecl(cName: thunkName)
    let getOutput = CodePrinter.toString { printer in
      st.printFunctionDescriptorValue(&printer, cFunc)
    }

    try body(getOutput)
  }
}
