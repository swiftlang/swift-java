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
struct JNIArrayTest {

  @Test("Import: (Array<UInt8>) -> Array<UInt8>")
  func uint8Array_explicitType_java() throws {
    try assertOutput(
      input: "public func f(array: Array<UInt8>) -> Array<UInt8> {}",
      .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        sdfad
        """,
        """
        sdf
        """,
      ]
    )
  }
}
