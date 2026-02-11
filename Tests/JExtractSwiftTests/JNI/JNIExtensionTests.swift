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
import Testing

@Suite
struct JNIExtensionTests {
  let interfaceFile =
    """
    extension MyStruct {
      public var variableInExtension: String { get }
      public func methodInExtension() {}
    }

    public protocol MyProtocol {}
    public struct MyStruct {}
    extension MyStruct: MyProtocol {}
    """

  @Test("Import extensions: Java methods")
  func import_javaMethods() throws {
    try assertOutput(
      input: interfaceFile,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public final class MyStruct implements JNISwiftInstance, MyProtocol {
          ...
          public void methodInExtension() {
          ...
        }
        """
      ]
    )
  }

  @Test("Import extensions: Computed variables")
  func import_computedVariables() throws {
    try assertOutput(
      input: interfaceFile,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public final class MyStruct implements JNISwiftInstance, MyProtocol {
          ...
          public java.lang.String getVariableInExtension() {
          ...
        }
        """
      ]
    )
  }
}
