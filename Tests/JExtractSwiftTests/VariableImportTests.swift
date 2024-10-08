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

final class VariableImportTests {
  let class_interfaceFile =
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

    public class MySwiftClass {
      public var counterInt: Int
    }
    """

  @Test("Import: var counter: Int")
  func variable_() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try await st.analyze(swiftInterfacePath: "/fake/Fake.swiftinterface", text: class_interfaceFile)

    let identifier = "counterInt"
    let varDecl: ImportedVariable? =
      st.importedTypes.values.compactMap {
          $0.variables.first {
            $0.identifier == identifier
          }
        }.first
    guard let varDecl else {
      fatalError("Cannot find: \(identifier)")
    }

    let output = CodePrinter.toString { printer in
      st.printVariableDowncallMethods(&printer, varDecl)
    }

    assertOutput(
      dump: true,
      output,
      expected:
      """
      // ==== --------------------------------------------------
      // counterInt
      private static class counterInt {
        public static final FunctionDescriptor DESC_GET =   FunctionDescriptor.of(
            /* -> */SWIFT_INT,
            SWIFT_POINTER
        );
        public static final FunctionDescriptor DESC_SET =   FunctionDescriptor.ofVoid(
            SWIFT_INT,
            SWIFT_POINTER
          );
      }
      /**
       * Function descriptor for:
       *
       */
      public static FunctionDescriptor counterInt$get$descriptor() {
          return counterInt.DESC_GET;
      }
      /**
       * Downcall method handle for:
       *
       */
      public static MethodHandle counterInt$get$handle() {
          return counterInt.HANDLE_GET;
      }
      /**
       * Address for:
       *
       */
      public static MemorySegment counterInt$get$address() {
          return counterInt.ADDR_GET;
      }
      /**
       * Function descriptor for:
       *
       */
      public static FunctionDescriptor counterInt$set$descriptor() {
          return counterInt.DESC_SET;
      }
      /**
       * Downcall method handle for:
       *
       */
      public static MethodHandle counterInt$set$handle() {
          return counterInt.HANDLE_SET;
      }
      /**
       * Address for:
       *
       */
      public static MemorySegment counterInt$set$address() {
          return counterInt.ADDR_SET;
      }
      """
    )
  }
}