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
  /// Read a configuration file from the given URL.
  package static func readConfiguration(from url: URL) throws -> Configuration {
    do {
      let contents = try Data(contentsOf: url)
      return try JSONDecoder().decode(Configuration.self, from: contents)
    } catch {
      // Make the error message useful by including which file we failed to decode
      throw ConfigurationError(message: "Failed to decode configuration: \(url)", error: error)
    }
  }

  /// Load the configuration file with the given name to populate the known set of
  /// translated Java classes.
  package func addConfiguration(_ config: Configuration, forSwiftModule swiftModule: String) {
    for (javaClassName, swiftName) in config.classes {
      translatedClasses[javaClassName] = (
        swiftType: swiftName,
        swiftModule: swiftModule
      )
    }
  }
}

struct ConfigurationError: Error {
  let message: String
  let error: any Error
}