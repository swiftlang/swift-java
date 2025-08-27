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
import SwiftJavaToolLib
import JExtractSwiftLib
import SwiftJava
import JavaUtilJar
import JavaNet
import JavaLangReflect
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftJavaConfigurationShared
import SwiftJavaShared

extension SwiftJava {
  struct ConfigureCommand: SwiftJavaBaseAsyncParsableCommand, HasCommonOptions, HasCommonJVMOptions {
    static let configuration = CommandConfiguration(
      commandName: "configure",
      abstract: "Configure and emit a swift-java.config file based on an input dependency or jar file")

    @OptionGroup var commonOptions: SwiftJava.CommonOptions
    @OptionGroup var commonJVMOptions: SwiftJava.CommonJVMOptions

    // TODO: This should be a "make wrappers" option that just detects when we give it a jar
    @Flag(
      help: "Specifies that the input is a *.jar file whose public classes will be loaded. The output of swift-java will be a configuration file (swift-java.config) that can be used as input to a subsequent swift-java invocation to generate wrappers for those public classes."
    )
    var jar: Bool = false

    @Option(
      name: .long,
      help: "How to handle an existing swift-java.config; by default 'overwrite' by can be changed to amending a configuration"
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

    @Argument(
      help: "The input file, which is either a swift-java configuration file or (if '-jar' was specified) a Jar file."
    )
    var input: String?
  }
}

extension SwiftJava.ConfigureCommand {
  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    let classpathEntries = self.configureCommandJVMClasspath(
        searchDirs: [self.effectiveSwiftModuleURL], config: config)

    let jvm =
      try self.makeJVM(classpathEntries: classpathEntries)

    try emitConfiguration(classpath: self.commonJVMOptions.classpath, environment: jvm.environment())
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
    classpath: [String],
    environment: JNIEnvironment
  ) throws {
    if let filterJavaPackage = self.commonJVMOptions.filterJavaPackage {
      print("[java-swift][debug] Generate Java->Swift type mappings. Active filter: \(filterJavaPackage)")
    }
    print("[java-swift][debug] Classpath: \(classpath)")

    if classpath.isEmpty {
      print("[java-swift][warning] Classpath is empty!")
    }

    // Get a fresh or existing configuration we'll amend
    var (amendExistingConfig, configuration) = try getBaseConfigurationForWrite()
    if amendExistingConfig {
      print("[swift-java] Amend existing swift-java.config file...")
    }
    configuration.classpath = classpath.joined(separator: ":") // TODO: is this correct?

    // Import types from all the classpath entries;
    // Note that we use the package level filtering, so users have some control over what gets imported.
    let classpathEntries = classpath.split(separator: ":").map(String.init)
    for entry in classpathEntries {
      guard fileOrDirectoryExists(at: entry) else {
        // We only log specific jars missing, as paths may be empty directories that won't hurt not existing.
        print("[debug][swift-java] Classpath entry does not exist: \(entry)")
        continue
      }

      print("[debug][swift-java] Importing classpath entry: \(entry)")
      if entry.hasSuffix(".jar") {
        let jarFile = try JarFile(entry, false, environment: environment)
        try addJavaToSwiftMappings(
          to: &configuration,
          forJar: jarFile,
          environment: environment
        )
      } else if FileManager.default.fileExists(atPath: entry) {
        print("[warning][swift-java] Currently unable handle directory classpath entries for config generation! Skipping: \(entry)")
      } else {
        print("[warning][swift-java] Classpath entry does not exist, skipping: \(entry)")
      }
    }

    // Encode the configuration.
    let contents = try configuration.renderJSON()

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
    forJar jarFile: JarFile,
    environment: JNIEnvironment
  ) throws {
    for entry in jarFile.entries()! {
      // We only look at class files in the Jar file.
      guard entry.getName().hasSuffix(".class") else {
        continue
      }

      // Skip some "common" files we know that would be duplicated in every jar
      guard !entry.getName().hasPrefix("META-INF") else {
        continue
      }
      guard !entry.getName().hasSuffix("package-info") else {
        continue
      }
      guard !entry.getName().hasSuffix("package-info.class") else {
        continue
      }

      // If this is a local class, it cannot be mapped into Swift.
      if entry.getName().isLocalJavaClass {
        continue
      }

      let javaCanonicalName = String(entry.getName().replacing("/", with: ".")
        .dropLast(".class".count))

      if let filterJavaPackage = self.commonJVMOptions.filterJavaPackage,
         !javaCanonicalName.hasPrefix(filterJavaPackage) {
        // Skip classes which don't match our expected prefix
        continue
      }

      if configuration.classes?[javaCanonicalName] != nil {
        // We never overwrite an existing class mapping configuration.
        // E.g. the user may have configured a custom name for a type.
        continue
      }

      configuration.classes?[javaCanonicalName] =
        javaCanonicalName.defaultSwiftNameForJavaClass
    }
  }

}

package func fileOrDirectoryExists(at path: String) -> Bool {
  var isDirectory: ObjCBool = false
  return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
}