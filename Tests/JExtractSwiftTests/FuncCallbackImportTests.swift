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

final class FuncCallbackImportTests {

  static let class_interfaceFile =
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

    public func callMe(callback: () -> ())
    """

  @Test("Import: public func callMe(callback: () -> ())")
  func func_callMeFunc_Runnable() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try st.analyze(file: "Fake.swift", text: Self.class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first { $0.name == "callMe" }!

    let output = CodePrinter.toString { printer in
      st.printJavaBindingWrapperMethod(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func callMe(callback: () -> ())
         * }
         */
        public static void callMe(java.lang.Runnable callback) {
          try(var arena$ = Arena.ofConfined()) {
            swiftjava___FakeModule_callMe_callback.call(SwiftKit.toUpcallStub(callback, arena$))
          }
        }
        """
    )
  }

}
