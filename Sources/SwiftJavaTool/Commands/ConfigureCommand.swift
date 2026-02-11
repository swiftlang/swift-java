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

import ArgumentParser
import Foundation
import JExtractSwiftLib
import JavaLangReflect
import JavaNet
import JavaUtilJar
import Logging
import SwiftJava
import SwiftJavaConfigurationShared
import SwiftJavaShared
import SwiftJavaToolLib
import SwiftSyntax
import SwiftSyntaxBuilder

extension SwiftJava {
  struct ConfigureCommand: SwiftJavaBaseAsyncParsableCommand, HasCommonOptions, HasCommonJVMOptions {

    static let log: Logging.Logger = Logger(label: "swift-java:\(configuration.commandName!)")

    static let configuration = CommandConfiguration(
      commandName: "configure",
      abstract: "Configure and emit a swift-java.config file based on an input dependency or jar file"
    )

    @OptionGroup var commonOptions: SwiftJava.CommonOptions
    @OptionGroup var commonJVMOptions: SwiftJava.CommonJVMOptions

    // TODO: This should be a "make wrappers" option that just detects when we give it a jar
    @Flag(
      help:
        "Specifies that the input is a *.jar file whose public classes will be loaded. The output of swift-java will be a configuration file (swift-java.config) that can be used as input to a subsequent swift-java invocation to generate wrappers for those public classes."
    )
    var jar: Bool = false

    @Option(
      name: .long,
      help:
        "How to handle an existing swift-java.config; by default 'overwrite' by can be changed to amending a configuration"
    )
    var existingConfigFile: ExistingConfigFileMode = .overwrite
    enum ExistingConfigFileMode: String, ExpressibleByArgument, Codable {
      case overwrite
      case amend
    }

    @Option(help: "The name of the Swift module into which the resulting Swift types will be generated.")
    var swiftModule: String

    var effectiveSwiftModule: String {
      swiftModule
    }

    @Option(help: "A prefix that will be added to the names of the Swift types")
    var swiftTypePrefix: String?
  }
}

extension SwiftJava.ConfigureCommand {
  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    let classpathEntries = self.configureCommandJVMClasspath(
      searchDirs: [self.effectiveSwiftModuleURL],
      config: config,
      log: Self.log
    )

    let jvm =
      try self.makeJVM(classpathEntries: classpathEntries)

    try emitConfiguration(classpathEntries: classpathEntries, environment: jvm.environment())
  }

  /// Get base configuration, depending on if we are to 'amend' or 'overwrite' the existing configuration.
  func getBaseConfigurationForWrite() throws -> (Bool, Configuration) {
    guard let actualOutputDirectory = self.actualOutputDirectory else {
      // If output has no path there's nothing to amend
      return (false, .init())
    }

    switch self.existingConfigFile {
    case .overwrite:
      // always make up a fresh instance if we're overwriting
      return (false, .init())
    case .amend:
      let configPath = actualOutputDirectory
      guard let config = try readConfiguration(sourceDir: configPath.path) else {
        return (false, .init())
      }
      return (true, config)
    }
  }

  // TODO: make this perhaps "emit type mappings"
  mutating func emitConfiguration(
    classpathEntries: [String],
    environment: JNIEnvironment
  ) throws {
    var log = Self.log
    log.logLevel = .init(rawValue: self.logLevel.rawValue)!

    log.info("Run: emit configuration...")
    var (amendExistingConfig, config) = try getBaseConfigurationForWrite()

    if !self.commonOptions.filterInclude.isEmpty {
      log.debug("Generate Java->Swift type mappings. Active include filters: \(self.commonOptions.filterInclude)")
    } else if let filters = config.filterInclude, !filters.isEmpty {
      // take the package filter from the configuration file
      self.commonOptions.filterInclude = filters
    } else {
      log.debug("Generate Java->Swift type mappings. No package include filter applied.")
    }
    log.debug("Classpath: \(classpathEntries)")

    if classpathEntries.isEmpty {
      log.warning("Classpath is empty!")
    }

    // Get a fresh or existing configuration we'll amend
    if amendExistingConfig {
      log.info("Amend existing swift-java.config file...")
    }
    config.classpath = classpathEntries.joined(separator: ":") // TODO: is this correct?

    // Import types from all the classpath entries;
    // Note that we use the package level filtering, so users have some control over what gets imported.
    for entry in classpathEntries {
      guard fileOrDirectoryExists(at: entry) else {
        // We only log specific jars missing, as paths may be empty directories that won't hurt not existing.
        log.debug("Classpath entry does not exist: \(entry)")
        continue
      }

      print("[debug][swift-java] Importing classpath entry: \(entry)")
      if entry.hasSuffix(".jar") {
        print("[debug][swift-java] Importing classpath as JAR file: \(entry)")
        let jarFile = try JarFile(entry, false, environment: environment)
        try addJavaToSwiftMappings(
          to: &config,
          forJar: jarFile,
          environment: environment
        )
      } else if FileManager.default.fileExists(atPath: entry), let entryURL = URL(string: entry) {
        print("[debug][swift-java] Importing classpath as directory: \(entryURL)")
        try addJavaToSwiftMappings(
          to: &config,
          forDirectory: entryURL
        )
      } else {
        log.warning("Classpath entry does not exist, skipping: \(entry)")
      }
    }

    // Encode the configuration.
    let contents = try config.renderJSON()

    // Write the file.
    try writeContents(
      contents,
      outputDirectory: self.actualOutputDirectory,
      to: "swift-java.config",
      description: "swift-java configuration file"
    )
  }

  mutating func addJavaToSwiftMappings(
    to configuration: inout Configuration,
    forDirectory url: Foundation.URL
  ) throws {
    let enumerator = FileManager.default.enumerator(atPath: url.path())

    while let filePath = enumerator?.nextObject() as? String {
      try addJavaToSwiftMappings(to: &configuration, fileName: filePath)
    }
  }

  mutating func addJavaToSwiftMappings(
    to configuration: inout Configuration,
    forJar jarFile: JarFile,
    environment: JNIEnvironment
  ) throws {
    for entry in jarFile.entries()! {
      try addJavaToSwiftMappings(to: &configuration, fileName: entry.getName())
    }
  }

  mutating func addJavaToSwiftMappings(
    to configuration: inout Configuration,
    fileName: String
  ) throws {
    // We only look at class files
    guard fileName.hasSuffix(".class") else {
      return
    }

    // Skip some "common" files we know that would be duplicated in every jar
    guard !fileName.hasPrefix("META-INF") else {
      return
    }
    guard !fileName.hasSuffix("package-info") else {
      return
    }
    guard !fileName.hasSuffix("package-info.class") else {
      return
    }

    // If this is a local class, it cannot be mapped into Swift.
    if fileName.isLocalJavaClass {
      return
    }

    let javaCanonicalName = String(
      fileName.replacing("/", with: ".")
        .dropLast(".class".count)
    )

    guard SwiftJava.shouldImport(javaCanonicalName: javaCanonicalName, commonOptions: self.commonOptions) else {
      log.info("Skip importing class: \(javaCanonicalName) due to include/exclude filters")
      return
    }

    if configuration.classes?[javaCanonicalName] != nil {
      // We never overwrite an existing class mapping configuration.
      // E.g. the user may have configured a custom name for a type.
      return
    }

    if configuration.classes == nil {
      configuration.classes = [:]
    }

    var swiftName = javaCanonicalName.defaultSwiftNameForJavaClass
    if let swiftTypePrefix {
      swiftName = "\(swiftTypePrefix)\(swiftName)"
    }

    if let configuredSwiftName = configuration.classes![javaCanonicalName] {
      log.info("Java type '\(javaCanonicalName)' already configured as '\(configuredSwiftName)' Swift type.")
    } else {
      log.info("Configure Java type '\(javaCanonicalName)' as '\(swiftName.bold)' Swift type.")
    }

    configuration.classes![javaCanonicalName] = swiftName
  }
}

package func fileOrDirectoryExists(at path: String) -> Bool {
  var isDirectory: ObjCBool = false
  return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
}
