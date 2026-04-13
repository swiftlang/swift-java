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

  /// The name of the native library to load at runtime via `System.loadLibrary()`.
  /// Defaults to the Swift module name when not set. Use this when the dynamic
  /// library product has a different name than the module being exported
  /// (e.g. the module is `MyLibrary` but the dylib is `MyLibrarySwiftJava` or something else).
  public var nativeLibraryName: String?

  /// When non-nil, overrides the library loading statements emitted in the
  /// `static {}` / `initializeLibs()` block of generated Java classes.
  /// Each string is emitted as a verbatim Java statement.
  ///
  /// When `nil` (the default), the standard loading calls are emitted.
  /// When set to an empty array `[]`, no library loading code is emitted at all.
  public var overrideStaticBlockLibraryLoading: [String]?

  public var inputSwiftDirectory: String?

  public var outputSwiftDirectory: String?

  public var outputJavaDirectory: String?

  public var mode: JExtractGenerationMode?
  public var effectiveMode: JExtractGenerationMode {
    mode ?? .default
  }

  public var writeEmptyFiles: Bool?
  public var effectiveWriteEmptyFiles: Bool {
    writeEmptyFiles ?? false
  }

  public var minimumInputAccessLevelMode: JExtractMinimumAccessLevelMode?
  public var effectiveMinimumInputAccessLevelMode: JExtractMinimumAccessLevelMode {
    minimumInputAccessLevelMode ?? .default
  }

  public var memoryManagementMode: JExtractMemoryManagementMode?
  public var effectiveMemoryManagementMode: JExtractMemoryManagementMode {
    memoryManagementMode ?? .default
  }

  public var asyncFuncMode: JExtractAsyncFuncMode?
  public var effectiveAsyncFuncMode: JExtractAsyncFuncMode {
    asyncFuncMode ?? .default
  }

  public var enableJavaCallbacks: Bool?
  public var effectiveEnableJavaCallbacks: Bool {
    enableJavaCallbacks ?? false
  }

  public var generatedJavaSourcesListFileOutput: String?

  /// If set, only generate bindings for this single Swift type name
  public var singleType: String?

  /// If set, JExtract (JNI mode) will write a linker version script to this
  /// path, listing all generated JNI ``@_cdecl`` entry-point symbols as
  /// global exports and hiding everything else with `local: *`. Pass this
  /// file to the linker via ``-Xlinker --version-script=<path>`` to enable
  /// precise dead-code elimination of unused Swift code in the final shared
  /// library.
  public var linkerExportListOutput: String?

  /// Include only Swift source files or types matching these patterns during jextract.
  /// File-path patterns (containing `/`): matched against relative file paths
  /// (including `.swift` extension). Supports `*` and `**` wildcards.
  /// Type-name patterns (containing `.`): matched against qualified type names
  /// (e.g. `Something.Other` for nested types).
  /// Plain names match both
  public var swiftFilterInclude: [String]?

  /// Exclude Swift source files or types matching these patterns during jextract.
  /// Same pattern syntax as swiftFilterInclude
  public var swiftFilterExclude: [String]?

  /// Stub type declarations for imported modules whose source is not available
  /// to the jextract tool. Keyed by module name, values are arrays of Swift
  /// declaration strings that will be parsed as if they belonged to that module.
  ///
  /// Example:
  /// ```json
  /// {
  ///   "importedModuleStubs": {
  ///     "ExternalModule": [
  ///       "public enum Outer {}",
  ///       "public struct Config {}"
  ///     ]
  ///   }
  /// }
  /// ```
  public var importedModuleStubs: [String: [String]]?

  /// Whether the given module name has stub declarations configured
  public func hasImportedModuleStub(moduleOfNominal moduleName: String) -> Bool {
    importedModuleStubs?.keys.contains(moduleName) ?? false
  }

  /// Specialization entries for generic types, mapping a Java-facing name
  /// to its base Swift type and concrete type arguments.
  ///
  /// Example:
  /// ```json
  /// {
  ///   "specialize": {
  ///     "FishBox": {
  ///       "base": "Box",
  ///       "typeArgs": {"Element": "Fish"}
  ///     },
  ///     "ToolBox": {
  ///       "base": "Box",
  ///       "typeArgs": {"Element": "Tool"}
  ///     }
  ///   }
  /// }
  /// ```
  public var specialize: [String: SpecializationConfigEntry]?

  /// If set, use this JSON file as the static build configuration for jextract.
  /// This allows users to provide a custom StaticBuildConfiguration for #if resolution.
  public var staticBuildConfigurationFile: String?

  // ==== wrap-java ---------------------------------------------------------

  /// The Java class path that should be passed along to the swift-java tool.
  public var classpath: String? = nil

  public var classpathEntries: [String] {
    classpath?.split(separator: ":").map(String.init) ?? []
  }

  /// The Java classes that should be translated to Swift. The keys are
  /// canonical Java class names (e.g., java.util.Vector) and the values are
  /// the corresponding Swift names (e.g., JavaVector).
  public var classes: [String: String]? = [:]

  // Compile for the specified Java SE release.
  public var sourceCompatibility: JavaVersion?

  // Generate class files suitable for the specified Java SE release.
  public var targetCompatibility: JavaVersion?

  /// Filter input Java types by their package prefix if set
  public var javaFilterInclude: [String]?

  /// Exclude input Java types by their package prefix or exact match
  public var javaFilterExclude: [String]?

  public var singleSwiftFileOutput: String?

  // ==== dependencies ---------------------------------------------------------

  // Java dependencies we need to fetch for this target.
  public var dependencies: [JavaDependencyDescriptor]?

  /// Custom Maven repositories to use when resolving dependencies.
  /// If not set, defaults to mavenCentral().
  public var mavenRepositories: [MavenRepositoryDescriptor]?

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
      throw JavaDependencyDescriptorError(
        message: "Illegal dependency, did not match: `groupID:artifactID:version`, parts: '\(parts)'"
      )
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

// ==== -----------------------------------------------------------------------
// MARK: MavenRepositoryDescriptor

/// Describes a Maven-style repository for dependency resolution.
///
/// Supported types based on https://docs.gradle.org/current/userguide/supported_repository_types.html:
/// - `maven(url:artifactUrls:)` — A custom Maven repository at the given URL
/// - `mavenCentral` — Maven Central repository
/// - `mavenLocal(includeGroups:)` — Local Maven cache (~/.m2/repository)
/// - `google` — Google's Maven repository
public enum MavenRepositoryDescriptor: Hashable, Codable {
  case maven(url: String, artifactUrls: [String]? = nil)
  case mavenCentral
  case mavenLocal(includeGroups: [String]? = nil)
  case google

  enum CodingKeys: String, CodingKey {
    case type
    case url
    case artifactUrls
    case includeGroups
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "maven":
      let url = try container.decode(String.self, forKey: .url)
      let artifactUrls = try container.decodeIfPresent([String].self, forKey: .artifactUrls)
      self = .maven(url: url, artifactUrls: artifactUrls)
    case "mavenCentral":
      self = .mavenCentral
    case "mavenLocal":
      let includeGroups = try container.decodeIfPresent([String].self, forKey: .includeGroups)
      self = .mavenLocal(includeGroups: includeGroups)
    case "google":
      self = .google
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "Unknown repository type: '\(type)'. Supported: maven, mavenCentral, mavenLocal, google",
      )
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .maven(let url, let artifactUrls):
      try container.encode("maven", forKey: .type)
      try container.encode(url, forKey: .url)
      try container.encodeIfPresent(artifactUrls, forKey: .artifactUrls)
    case .mavenCentral:
      try container.encode("mavenCentral", forKey: .type)
    case .mavenLocal(let includeGroups):
      try container.encode("mavenLocal", forKey: .type)
      try container.encodeIfPresent(includeGroups, forKey: .includeGroups)
    case .google:
      try container.encode("google", forKey: .type)
    }
  }

  /// Render this repository as Gradle DSL.
  public var gradleDSL: String {
    switch self {
    case .maven(let url, let artifactUrls):
      var result = "maven {\n"
      result += "    url = uri(\"\(url)\")\n"
      if let artifactUrls, !artifactUrls.isEmpty {
        result += "    artifactUrls = [\(artifactUrls.map { "\"\($0)\"" }.joined(separator: ", "))]\n"
      }
      result += "}"
      return result
    case .mavenCentral:
      return "mavenCentral()"
    case .mavenLocal(let includeGroups):
      if let includeGroups, !includeGroups.isEmpty {
        var result = "mavenLocal {\n"
        result += "    content {\n"
        for group in includeGroups {
          result += "        includeGroup(\"\(group)\")\n"
        }
        result += "    }\n"
        result += "}"
        return result
      }
      return "mavenLocal()"
    case .google:
      return "google()"
    }
  }
}

public func readConfiguration(sourceDir: URL, file: String = #fileID, line: UInt = #line) throws -> Configuration? {
  let configPath = sourceDir.appendingPathComponent("swift-java.config", isDirectory: false)
  return try readConfiguration(configPath: configPath, file: file, line: line)
}

/// Read a swift-java.config file at the specified path.
///
/// Configuration is expected to be "JSON-with-comments".
/// Specifically "//" comments are allowed and will be trimmed before passing the rest of the config into a standard JSON parser.
public func readConfiguration(configPath: URL, file: String = #fileID, line: UInt = #line) throws -> Configuration? {
  let configData: Data
  do {
    configData = try Data(contentsOf: configPath)
  } catch {
    print("Failed to read SwiftJava configuration at '\(configPath.absoluteURL)', error: \(error)")
    return nil
  }

  guard let configString = String(data: configData, encoding: .utf8) else {
    return nil
  }

  return try readConfiguration(string: configString, configPath: configPath)
}

public func readConfiguration(
  string: String,
  configPath: URL?,
  file: String = #fileID,
  line: UInt = #line,
) throws -> Configuration? {
  guard let configData = string.data(using: .utf8) else {
    return nil
  }

  do {
    let decoder = JSONDecoder()
    decoder.allowsJSON5 = true
    return try decoder.decode(Configuration.self, from: configData)
  } catch {
    throw ConfigurationError(
      message:
        "Failed to parse SwiftJava configuration at '\(configPath.map({ $0.absoluteURL.description }) ?? "<no-path>")'! \(#fileID):\(#line)",
      error: error,
      text: string,
      file: file,
      line: line,
    )
  }
}

/// Parsed dependent configuration provided via `--depends-on`.
public struct DependentConfig {
  public let swiftModuleName: String?
  public let configuration: Configuration

  public init(swiftModuleName: String?, configuration: Configuration) {
    self.swiftModuleName = swiftModuleName
    self.configuration = configuration
  }
}

/// Load all dependent configs configured with `--depends-on`.
public func loadDependentConfigs(dependsOn: [String]) throws -> [DependentConfig] {
  try dependsOn.map { dependentConfig in
    let equalLoc = dependentConfig.firstIndex(of: "=")

    var swiftModuleName: String? = nil
    if let equalLoc {
      swiftModuleName = String(dependentConfig[..<equalLoc])
    }

    let afterEqual = equalLoc.map { dependentConfig.index(after: $0) } ?? dependentConfig.startIndex
    let configFileName = String(dependentConfig[afterEqual...])

    let config = try readConfiguration(configPath: URL(fileURLWithPath: configFileName)) ?? Configuration()

    return DependentConfig(swiftModuleName: swiftModuleName, configuration: config)
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
      if let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
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
  let text: String?

  let file: String
  let line: UInt

  init(message: String, error: any Error, text: String?, file: String = #fileID, line: UInt = #line) {
    self.message = message
    self.error = error
    self.text = text
    self.file = file
    self.line = line
  }
}

// ==== -----------------------------------------------------------------------
// MARK: SpecializationConfigEntry

/// Configuration entry for specializing a generic type into a concrete Java class.
/// The dictionary key is the Java-facing name; this entry provides the base type
/// and type argument mapping.
public struct SpecializationConfigEntry: Codable, Sendable {
  /// The base Swift type name (e.g. "Box")
  public var base: String

  /// Mapping from generic parameter name to concrete type (e.g. {"Element": "Fish"})
  public var typeArgs: [String: String]

  public init(base: String, typeArgs: [String: String]) {
    self.base = base
    self.typeArgs = typeArgs
  }
}

public enum LogLevel: String, ExpressibleByStringLiteral, Codable, Hashable {
  case trace = "trace"
  case debug = "debug"
  case info = "info"
  case notice = "notice"
  case warning = "warning"
  case error = "error"
  case critical = "critical"

  public init(stringLiteral value: String) {
    self = LogLevel(rawValue: value) ?? .info
  }
}

extension LogLevel {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
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
