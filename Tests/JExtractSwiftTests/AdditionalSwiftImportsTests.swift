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

final class AdditionalSwiftImportsTests {
  let interfaceFile =
    """
    public struct MyStruct {}
    """

  @Test("Import with additional imports")
  func data_swiftThunk() throws {
    var config = Configuration() 
    config.swiftAdditionalImports = ["Extras", "Additional"]
    try assertOutput(
      input: interfaceFile, 
      config: config,
      .ffm, .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        import Extras // additional import, requested through tool invocation
        import Additional // additional import, requested through tool invocation
        """
      ]
    )
  }
}
