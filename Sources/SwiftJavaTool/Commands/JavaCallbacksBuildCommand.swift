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
import Subprocess

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

extension SwiftJava {
  /// Builds Swift-Java callbacks in a single command:
  /// 1. Building SwiftKitCore with Gradle
  /// 2. Compiling extracted Java sources with javac
  /// 3. Running `swift-java configure` to produce a swift-java.config
  /// 4. Running `swift-java wrap-java` to generate Swift wrappers
  ///
  /// **WORKAROUND**: rdar://172649681 if we invoke commands one by one with java outputs SwiftPM will link Foundation
  ///
  /// This command is used by ``JExtractSwiftPlugin`` to consolidate all of the above
  /// into a single build command that declares only a Swift file as its output,
  /// avoiding SPM treating intermediate Java artifacts (compiled classes, config files,
  /// Gradle output directories) as module resources, which would trigger
  /// resource_bundle_accessor.swift generation and pull Foundation.Bundle into the binary.
  struct JavaCallbacksBuildCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
      commandName: "java-callbacks-build",
      abstract:
        "Build SwiftKitCore, compile Java callbacks, and generate Swift wrappers (for use by JExtractSwiftPlugin)",
      shouldDisplay: false,
    )

    // MARK: Gradle options

    @Option(help: "Path to the gradle (or gradlew) executable")
    var gradleExecutable: String

    @Option(help: "The Gradle project directory (passed as --project-dir)")
    var gradleProjectDir: String

    @Option(help: "The Gradle user home directory (GRADLE_USER_HOME)")
    var gradleUserHome: String

    // MARK: javac options

    @Option(help: "Path to the javac executable")
    var javac: String

    @Option(help: "Path to the @-file listing Java sources to compile")
    var javaSourcesList: String

    @Option(help: "Directory where compiled Java classes should be output")
    var javaOutputDirectory: String

    @Option(help: "Path to SwiftKitCore compiled classes (classpath for javac and wrap-java)")
    var swiftKitCoreClasspath: String

    // MARK: Swift generation options

    @Option(help: "The name of the Swift module")
    var swiftModule: String

    @Option(help: "Prefix to add to generated Swift type names")
    var swiftTypePrefix: String?

    @Option(
      name: .customLong("output-directory"),
      help: "Directory where generated Swift files should be written",
    )
    var outputDirectory: String

    @Option(help: "Name of the single Swift output file")
    var singleSwiftFileOutput: String

    @Option(help: "Path to the swift-java tool executable (used to invoke subcommands)")
    var swiftJavaTool: String

    @Option(
      help:
        "Dependent module configurations (format: ModuleName=/path/to/swift-java.config)"
    )
    var dependsOn: [String] = []

    mutating func run() async throws {
      let outputDir = URL(fileURLWithPath: outputDirectory)
      let outputFile = outputDir.appendingPathComponent(singleSwiftFileOutput)

      // 1. Build SwiftKitCore using Gradle.
      try await runSubprocess(
        executable: gradleExecutable,
        arguments: [
          ":SwiftKitCore:build",
          "--project-dir", gradleProjectDir,
          "--gradle-user-home", gradleUserHome,
          "--configure-on-demand",
          "--no-daemon",
        ],
        environment: .inherit.updating(["GRADLE_USER_HOME": gradleUserHome]),
        errorMessage: "gradle :SwiftKitCore:build",
      )

      // If the sources list does not exist, jextract produced no Java callbacks.
      // Write an empty placeholder Swift file and return early.
      guard FileManager.default.fileExists(atPath: javaSourcesList) else {
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        try "// No Java callbacks generated\n".write(
          to: outputFile,
          atomically: true,
          encoding: .utf8,
        )
        return
      }

      // 2. Compile Java sources with javac.
      try FileManager.default.createDirectory(
        atPath: javaOutputDirectory,
        withIntermediateDirectories: true,
      )

      try await runSubprocess(
        executable: javac,
        arguments: [
          "@\(javaSourcesList)",
          "-d", javaOutputDirectory,
          "-parameters",
          "-classpath", swiftKitCoreClasspath,
        ],
        errorMessage: "javac",
      )

      // 3. Generate swift-java.config from compiled classes.
      //    Written into javaOutputDirectory (inside pluginWorkDirectory) but NOT
      //    declared as a build command output, so SPM will not bundle it as a resource.
      var configureArgs = [
        "configure",
        "--output-directory", javaOutputDirectory,
        "--cp", javaOutputDirectory,
        "--swift-module", swiftModule,
      ]
      if let prefix = swiftTypePrefix {
        configureArgs += ["--swift-type-prefix", prefix]
      }

      try await runSubprocess(
        executable: swiftJavaTool,
        arguments: configureArgs,
        errorMessage: "swift-java configure",
      )

      // 4. Generate Swift wrappers using wrap-java.
      let configPath = URL(fileURLWithPath: javaOutputDirectory)
        .appendingPathComponent("swift-java.config").path

      var wrapJavaArgs = [
        "wrap-java",
        "--swift-module", swiftModule,
        "--output-directory", outputDirectory,
        "--config", configPath,
        "--cp", swiftKitCoreClasspath,
        "--single-swift-file-output", singleSwiftFileOutput,
      ]
      wrapJavaArgs += dependsOn.flatMap { ["--depends-on", $0] }

      try await runSubprocess(
        executable: swiftJavaTool,
        arguments: wrapJavaArgs,
        errorMessage: "swift-java wrap-java",
      )
    }
  }
}

// MARK: - Helpers

private func runSubprocess(
  executable: String,
  arguments: [String],
  environment: Subprocess.Environment = .inherit,
  errorMessage: String,
) async throws {
  let result = try await Subprocess.run(
    .path(FilePath(executable)),
    arguments: .init(arguments),
    environment: environment,
    output: .standardOutput,
    error: .standardError,
  )
  guard result.terminationStatus.isSuccess else {
    throw JavaCallbacksBuildError(
      "\(errorMessage) failed with exit status \(result.terminationStatus)"
    )
  }
}

struct JavaCallbacksBuildError: Error, CustomStringConvertible {
  let description: String
  init(_ message: String) { self.description = message }
}
