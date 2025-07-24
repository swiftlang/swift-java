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

final class UnsignedTests {
  let interfaceFile =
    """
    public func unsignedInt(_ arg: UInt32)
    """


  @Test("Import: UInt32")
  func unsignedInt() throws {

    try assertOutput(
      input: interfaceFile, .ffm, .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static void unsignedInt(org.swift.swiftkit.core.primitives.UnsignedInteger arg) {
          swiftjava_SwiftModule_unsignedInt__.call(UnsignedNumbers.toPrimitive(arg));
        }
        """,
      ]
    )
  }
}
