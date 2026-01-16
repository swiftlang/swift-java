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
import SwiftJavaConfigurationShared

struct FoundationImportTests {
  @Test("Import Foundation", arguments: [JExtractGenerationMode.jni, JExtractGenerationMode.ffm])
  func import_foundation(mode: JExtractGenerationMode) throws {

    try assertOutput(
      input: "import Foundation", mode, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "import Foundation"
      ]
    )
  }

  @Test("Import FoundationEssentials", arguments: [JExtractGenerationMode.jni, JExtractGenerationMode.ffm])
  func import_foundationEssentials(mode: JExtractGenerationMode) throws {

    try assertOutput(
      input: "import FoundationEssentials", mode, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "import FoundationEssentials"
      ]
    )
  }

  @Test("Import conditional foundation", arguments: [JExtractGenerationMode.jni, JExtractGenerationMode.ffm])
  func import_conditionalFoundation(mode: JExtractGenerationMode) throws {
    let ifConfigImport =
      """
      #if canImport(FoundationEssentials)
      import FoundationEssentials
      #else
      import Foundation
      #endif
      """

    try assertOutput(
      input: ifConfigImport, mode, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        ifConfigImport
      ]
    )
  }
}
