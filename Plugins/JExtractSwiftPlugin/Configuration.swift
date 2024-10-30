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

/// Configuration for the JExtractSwift translation tool, provided on a per-target
/// basis.
struct Configuration: Codable {
  var javaPackage: String
}

func readConfiguration(sourceDir: String) throws -> Configuration {
  let configFile = URL(filePath: sourceDir).appending(path: "JExtractSwift.config")
  do {
    let configData = try Data(contentsOf: configFile)
    return try JSONDecoder().decode(Configuration.self, from: configData)
  } catch {
    throw ConfigurationError(message: "Failed to parse JExtractSwift configuration at '\(configFile)!'", error: error)
  }
}

struct ConfigurationError: Error {
  let message: String
  let error: any Error
}
