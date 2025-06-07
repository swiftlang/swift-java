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

import JExtractSwiftLib
import Testing

struct ClassPrintingTests {
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
      public init(len: Swift.Int, cap: Swift.Int)

      public func helloMemberFunction()

      public func makeInt() -> Int

      @objc deinit
    }
    """

  @Test("Import: class layout")
  func class_layout() throws {
    let st = Swift2JavaTranslator(
      swiftModuleName: "__FakeModule"
    )

    try assertOutput(st, input: class_interfaceFile, .java, expectedChunks: [
      """
      public static final SwiftAnyType TYPE_METADATA =
          new SwiftAnyType(SwiftKit.swiftjava.getType("__FakeModule", "MySwiftClass"));
      public final SwiftAnyType $swiftType() {
          return TYPE_METADATA;
      }

      public static final GroupLayout $LAYOUT = (GroupLayout) SwiftValueWitnessTable.layoutOfSwiftType(TYPE_METADATA.$memorySegment());
      public final GroupLayout $layout() {
          return $LAYOUT;
      }
      """
    ])
  }
}
