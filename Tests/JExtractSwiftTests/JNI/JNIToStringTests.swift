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
import SwiftJavaConfigurationShared

@Suite
struct JNIToStringTests {

  @Test("Import: CustomStringConvertible in type decl")
  func customStringConvertible_typeDecl() throws {
    try assertOutput(
      input:
        """
        public struct MyType: CustomStringConvertible {
          public var description: String { get }
        }
        """,
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public java.lang.String getDescription() {
        """,
        """
        public String toString() {
          return this.getDescription();
        }
        """
      ]
    )
  }

  @Test("Import: CustomStringConvertible in extension decl")
  func customStringConvertible_extension() throws {
    try assertOutput(
      input:
        """
        public struct MyType {}
        
        extension MyType: CustomStringConvertible {
          public var description: String { get }
        }
        """,
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public java.lang.String getDescription() {
        """,
        """
        public String toString() {
          return this.getDescription();
        }
        """
      ]
    )
  }
}
