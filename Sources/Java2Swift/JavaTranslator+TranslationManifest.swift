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

import Foundation

extension JavaTranslator {
  /// Load the manifest file with the given name to populate the known set of
  /// translated Java classes.
  func loadTranslationManifest(from url: URL) throws {
    let contents = try Data(contentsOf: url)
    let manifest = try JSONDecoder().decode(TranslationManifest.self, from: contents)
    for (javaClassName, swiftName) in manifest.translatedClasses {
      translatedClasses[javaClassName] = (
        swiftType: swiftName,
        swiftModule: manifest.swiftModule,
        isOptional: true
      )
    }
  }

  /// Emit the translation manifest for this source file
  func encodeTranslationManifest() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var contents = String(data: try encoder.encode(manifest), encoding: .utf8)!
    contents.append("\n")
    return contents
  }
}
