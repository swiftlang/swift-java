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

typealias JavaVersion = Int

/// Configuration for the SwiftJava plugins, provided on a per-target basis.
struct Configuration: Codable {
  // ==== swift 2 java ---------------------------------------------------------

  var javaPackage: String?

  // ==== java 2 swift ---------------------------------------------------------

  /// The Java class path that should be passed along to the Java2Swift tool.
  var classPath: String? = nil

  /// The Java classes that should be translated to Swift. The keys are
  /// canonical Java class names (e.g., java.util.Vector) and the values are
  /// the corresponding Swift names (e.g., JavaVector).
  var classes: [String: String]? = [:]

  // Compile for the specified Java SE release.
  var sourceCompatibility: JavaVersion?

  // Generate class files suitable for the specified Java SE release.
  var targetCompatibility: JavaVersion?
}

func readConfiguration(sourceDir: String, file: String = #fileID, line: UInt = #line) throws -> Configuration {
  let configFile = URL(filePath: sourceDir).appending(path: "swift-java.config")
  do {
    let configData = try Data(contentsOf: configFile)
    return try JSONDecoder().decode(Configuration.self, from: configData)
  } catch {
    throw ConfigurationError(message: "Failed to parse SwiftJava configuration at '\(configFile)!'", error: error,
      file: file, line: line)
  }
}

extension Configuration {
  var compilerVersionArgs: [String] {
    var compilerVersionArgs = [String]()

    if let sourceCompatibility {
      compilerVersionArgs += ["--source", String(sourceCompatibility)]
    }
    if let targetCompatibility {
      compilerVersionArgs += ["--target", String(targetCompatibility)]
    }

    return compilerVersionArgs
  }
}

struct ConfigurationError: Error {
  let message: String
  let error: any Error

  let file: String
  let line: UInt

  init(message: String, error: any Error, file: String = #fileID, line: UInt = #line) {
    self.message = message
    self.error = error
    self.file = file
    self.line = line
  }
}
