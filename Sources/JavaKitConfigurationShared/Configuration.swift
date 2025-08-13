//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
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

/// Configuration for the SwiftJava tools and plugins, provided on a per-target basis.
public struct Configuration: Codable {

  public var logLevel: LogLevel?

  // ==== swift 2 java / jextract swift ---------------------------------------

  public var javaPackage: String?

  public var swiftModule: String?

  public var inputSwiftDirectory: String?

  public var outputSwiftDirectory: String?

  public var outputJavaDirectory: String?

  public var mode: JExtractGenerationMode?

  public var writeEmptyFiles: Bool? // FIXME: default it to false, but that plays not nice with Codable

  public var unsignedNumbersMode: JExtractUnsignedIntegerMode?
  public var effectiveUnsignedNumbersMode: JExtractUnsignedIntegerMode {
    unsignedNumbersMode ?? .default
  }
  public var minimumInputAccessLevelMode: JExtractMinimumAccessLevelMode?
  public var effectiveMinimumInputAccessLevelMode: JExtractMinimumAccessLevelMode {
    minimumInputAccessLevelMode ?? .default
  }

  public var memoryManagementMode: JExtractMemoryManagementMode?
  public var effectiveMemoryManagementMode: JExtractMemoryManagementMode {
    memoryManagementMode ?? .default
  }

  // ==== java 2 swift ---------------------------------------------------------

  /// The Java class path that should be passed along to the swift-java tool.
  public var classpath: String? = nil

  public var classpathEntries: [String] {
    return classpath?.split(separator: ":").map(String.init) ?? []
  }

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

  public init(groupID: String, artifactID: String, version: String) {
    self.groupID = groupID
    self.artifactID = artifactID
    self.version = version
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    let parts = string.split(separator: ":")
    
    if parts.count == 1 && string.hasPrefix(":") {
      self.groupID = ""
      self.artifactID = ":" + String(parts.first!)
      self.version = ""
      return
    }
    
    guard parts.count == 3 else {
      throw JavaDependencyDescriptorError(message: "Illegal dependency, did not match: `groupID:artifactID:version`, parts: '\(parts)'")
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

public func readConfiguration(sourceDir: String, file: String = #fileID, line: UInt = #line) throws -> Configuration? {
  // Workaround since filePath is macOS 13
  let sourcePath =
  if sourceDir.hasPrefix("file://") { sourceDir } else { "file://" + sourceDir }
  let configPath = URL(string: sourcePath)!.appendingPathComponent("swift-java.config", isDirectory: false)
  
  return try readConfiguration(configPath: configPath, file: file, line: line)
}

public func readConfiguration(configPath: URL, file: String = #fileID, line: UInt = #line) throws -> Configuration? {
  guard let configData = try? Data(contentsOf: configPath) else {
    return nil
  }

  do {
    return try JSONDecoder().decode(Configuration.self, from: configData)
  } catch {
    throw ConfigurationError(message: "Failed to parse SwiftJava configuration at '\(configPath.absoluteURL)'! \(#fileID):\(#line)", error: error,
      file: file, line: line)
  }
}

/// Load all dependent configs configured with `--depends-on` and return a list of
/// `(SwiftModuleName, Configuration)` tuples.
public func loadDependentConfigs(dependsOn: [String]) throws -> [(String?, Configuration)] {
  try dependsOn.map { dependentConfig in
    let equalLoc = dependentConfig.firstIndex(of: "=")

    var swiftModuleName: String? = nil
    if let equalLoc {
      swiftModuleName = String(dependentConfig[..<equalLoc])
    }

    let afterEqual = equalLoc.map { dependentConfig.index(after: $0) } ?? dependentConfig.startIndex
    let configFileName = String(dependentConfig[afterEqual...])

    let config = try readConfiguration(configPath: URL(fileURLWithPath: configFileName)) ?? Configuration()

    return (swiftModuleName, config)
  }
}

public func findSwiftJavaClasspaths(swiftModule: String) -> [String] {
  let basePath: String = FileManager.default.currentDirectoryPath
  let pluginOutputsDir = URL(fileURLWithPath: basePath)
    .appendingPathComponent(".build", isDirectory: true)
    .appendingPathComponent("plugins", isDirectory: true)
    .appendingPathComponent("outputs", isDirectory: true)
    .appendingPathComponent(swiftModule, isDirectory: true)

  return findSwiftJavaClasspaths(in: pluginOutputsDir.path)
}

public func findSwiftJavaClasspaths(in basePath: String = FileManager.default.currentDirectoryPath) -> [String] {
  let fileManager = FileManager.default

  let baseURL = URL(fileURLWithPath: basePath)
  var classpathEntries: [String] = []

  print("[debug][swift-java] Searching for *.swift-java.classpath files in: \(baseURL.absoluteString)")
  guard let enumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: []) else {
    print("[warning][swift-java] Failed to get enumerator for \(baseURL)")
    return []
  }
  
  for case let fileURL as URL in enumerator {
    if fileURL.lastPathComponent.hasSuffix(".swift-java.classpath") {
      print("[debug][swift-java] Constructing classpath with entries from: \(fileURL.path)")
      if let contents = try? String(contentsOf: fileURL) {
        let entries = contents.split(separator: ":").map(String.init)
        for entry in entries {
          print("[debug][swift-java] Classpath += \(entry)")
        }
        classpathEntries += entries
      }
    }
  }

  return classpathEntries
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

public enum LogLevel: String, Codable, Hashable {
  case trace = "trace"
  case debug = "debug"
  case info = "info"
  case notice = "notice"
  case warning = "warning"
  case error = "error"
  case critical = "critical"
}

extension LogLevel {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    let string = try container.decode(String.self)
    switch string {
    case "trace": self = .trace
    case "debug": self = .debug
    case "info": self = .info
    case "notice": self = .notice
    case "warning": self = .warning
    case "error": self = .error
    case "critical": self = .critical
    default: fatalError("Unknown value for \(LogLevel.self): \(string)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    let text =
      switch self {
      case .trace: "trace"
      case .debug: "debug"
      case .info: "info"
      case .notice: "notice"
      case .warning: "warning"
      case .error: "error"
      case .critical: "critical"
      }
    try container.encode(text)
  }
}
