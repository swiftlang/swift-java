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

////////////////////////////////////////////////////////////////////////////////
// This file is only supposed to be edited in `Shared/` and must be symlinked //
// from everywhere else! We cannot share dependencies with or between plugins //
////////////////////////////////////////////////////////////////////////////////

public typealias JavaVersion = Int

/// Configuration for the SwiftJava plugins, provided on a per-target basis.
public struct Configuration: Codable {
  // ==== swift 2 java ---------------------------------------------------------

  public var javaPackage: String?

  // ==== java 2 swift ---------------------------------------------------------

  /// The Java class path that should be passed along to the Java2Swift tool.
  public var classpath: String? = nil

  /// The Java classes that should be translated to Swift. The keys are
  /// canonical Java class names (e.g., java.util.Vector) and the values are
  /// the corresponding Swift names (e.g., JavaVector).
  public var classes: [String: String]? = [:]

  // Compile for the specified Java SE release.
  public var sourceCompatibility: JavaVersion?

  // Generate class files suitable for the specified Java SE release.
  public var targetCompatibility: JavaVersion?

  // ==== dependencies ---------------------------------------------------------

  // Java dependencies we need to fetch for this target.
  public var dependencies: [JavaDependencyDescriptor]?

  public init() {
  }

}

/// Represents a maven-style Java dependency.
public struct JavaDependencyDescriptor: Hashable, Codable {
  public var groupID: String
  public var artifactID: String
  public var version: String

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    let parts = string.split(separator: ":")
    guard parts.count == 3 else {
      throw JavaDependencyDescriptorError(message: "Illegal dependency, did not match: `groupID:artifactID:version`")
    }
    self.groupID = String(parts[0])
    self.artifactID = String(parts[1])
    self.version = String(parts[2])
  }

  public var descriptionGradleStyle: String {
    [groupID, artifactID, version].joined(separator: ":")
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode("\(self.groupID):\(self.artifactID):\(self.version)")
  }

  struct JavaDependencyDescriptorError: Error {
    let message: String
  }
}

public func readConfiguration(sourceDir: String, file: String = #fileID, line: UInt = #line) throws -> Configuration {
  let sourcePath =
    if sourceDir.hasPrefix("file://") { sourceDir } else { "file://" + sourceDir }
  let configFile = URL(string: sourcePath)!.appendingPathComponent("swift-java.config", isDirectory: false)

  do {
    let configData = try Data(contentsOf: configFile)
    return try JSONDecoder().decode(Configuration.self, from: configData)
  } catch {
    throw ConfigurationError(message: "Failed to parse SwiftJava configuration at '\(configFile)'!", error: error,
      file: file, line: line)
  }
}

extension Configuration {
  public var compilerVersionArgs: [String] {
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

extension Configuration {
  /// Render the configuration as JSON text.
  public func renderJSON() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var contents = String(data: try encoder.encode(self), encoding: .utf8)!
    contents.append("\n")
    return contents
  }
}

public struct ConfigurationError: Error {
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
