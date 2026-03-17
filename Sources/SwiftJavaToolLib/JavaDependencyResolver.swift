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

import CodePrinting
import Foundation
import Subprocess
import SwiftJavaConfigurationShared

#if canImport(System)
import System
#else
@preconcurrency import SystemPackage
#endif

// ==== -----------------------------------------------------------------------
// MARK: JavaDependencyResolver

/// Resolves Java/Maven dependencies using Gradle, with support for custom repositories.
///
/// The resolver creates a temporary Gradle project, runs dependency resolution,
/// and returns the resulting classpath.
public struct JavaDependencyResolver {

  static let SwiftJavaClasspathPrefix = "SWIFT_JAVA_CLASSPATH:"
  static let printRuntimeClasspathTaskName = "printRuntimeClasspath"

  // ==== -------------------------------------------------------------------
  // MARK: API

  /// Resolve dependencies and return the classpath string.
  ///
  /// - Parameters:
  ///   - config: Configuration containing dependencies and optional repositories.
  ///   - workDir: Working directory for creating the temporary Gradle project.
  /// - Returns: Colon-separated classpath string of resolved dependencies.
  public static func resolve(
    config: SwiftJavaConfigurationShared.Configuration,
    workDir: URL
  ) async throws -> String {
    let dependencies = config.dependencies ?? []
    guard !dependencies.isEmpty else {
      throw JavaDependencyResolverError.noDependencies
    }

    let resolverDir = try createTemporaryDirectory(in: workDir)
    defer {
      try? FileManager.default.removeItem(at: resolverDir)
    }

    try copyGradlew(to: resolverDir)
    try writeGradleProject(
      directory: resolverDir,
      dependencies: dependencies,
      repositories: config.mavenRepositories ?? [.mavenCentral]
    )

    return try await runGradle(in: resolverDir)
  }

  // ==== -------------------------------------------------------------------
  // MARK: Gradle project generation

  /// Write build.gradle and settings.gradle.kts into the given directory.
  static func writeGradleProject(
    directory: URL,
    dependencies: [JavaDependencyDescriptor],
    repositories: [MavenRepositoryDescriptor] = [.mavenCentral]
  ) throws {
    let buildGradleText = printBuildGradle(dependencies: dependencies, repositories: repositories)
    let buildGradle = directory.appendingPathComponent("build.gradle", isDirectory: false)
    try buildGradleText.write(to: buildGradle, atomically: true, encoding: .utf8)

    let settingsGradle = directory.appendingPathComponent("settings.gradle.kts", isDirectory: false)
    let settingsGradleText = """
      rootProject.name = "swift-java-resolve-temp-project"
      """
    try settingsGradleText.write(to: settingsGradle, atomically: true, encoding: .utf8)
  }

  /// Generate the Gradle build file content as a string.
  public static func printBuildGradle(
    dependencies: [JavaDependencyDescriptor],
    repositories: [MavenRepositoryDescriptor]
  ) -> String {
    var p = CodePrinter()
    p.indentationPart = "    "

    p.print("plugins { id 'java-library' }")

    p.printBraceBlock("repositories") { p in
      for repo in repositories {
        p.print(repo.gradleDSL)
      }
    }

    p.println()

    p.printBraceBlock("dependencies") { p in
      for dep in dependencies {
        p.print("implementation(\"\(dep.descriptionGradleStyle)\")")
      }
    }

    p.println()

    p.printBraceBlock("tasks.register(\"\(printRuntimeClasspathTaskName)\")") { p in
      p.print("def runtimeClasspath = sourceSets.main.runtimeClasspath")
      p.print("inputs.files(runtimeClasspath)")
      p.printBraceBlock("doLast") { p in
        p.print("println(\"\(SwiftJavaClasspathPrefix)${runtimeClasspath.asPath}\")")
      }
    }

    return p.finalize()
  }

  // ==== -------------------------------------------------------------------
  // MARK: Gradle execution

  static func runGradle(in resolverDir: URL) async throws -> String {
    let process = try await Subprocess.run(
      .path(FilePath(resolverDir.appendingPathComponent("gradlew").path)),
      arguments: [
        "--no-daemon",
        "--rerun-tasks",
        printRuntimeClasspathTaskName,
      ],
      workingDirectory: Optional(FilePath(resolverDir.path)),
      output: .string(limit: Int.max, encoding: UTF8.self),
      error: .string(limit: Int.max, encoding: UTF8.self)
    )

    let outString = process.standardOutput ?? ""
    let errString = process.standardError ?? ""

    if let found = outString.split(separator: "\n").first(where: { $0.hasPrefix(SwiftJavaClasspathPrefix) }) {
      return String(found.dropFirst(SwiftJavaClasspathPrefix.count))
    } else if let found = errString.split(separator: "\n").first(where: { $0.hasPrefix(SwiftJavaClasspathPrefix) }) {
      return String(found.dropFirst(SwiftJavaClasspathPrefix.count))
    }

    throw JavaDependencyResolverError.gradleFailed(
      message: "Gradle output had no SWIFT_JAVA_CLASSPATH. "
        + "It may be that the Sandbox has prevented dependency fetching, please re-run with '--disable-sandbox'.\n"
        + "Output: \(outString)\nErr: \(errString)"
    )
  }

  // ==== -------------------------------------------------------------------
  // MARK: File utilities

  static func createTemporaryDirectory(in directory: URL) throws -> URL {
    let uuid = UUID().uuidString
    let resolverDirectoryURL = directory.appendingPathComponent("swift-java-dependencies-\(uuid)")
    try FileManager.default.createDirectory(
      at: resolverDirectoryURL,
      withIntermediateDirectories: true,
      attributes: nil
    )
    return resolverDirectoryURL
  }

  static func copyGradlew(to resolverWorkDirectory: URL) throws {
    var searchDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    while searchDir.pathComponents.count > 1 {
      let gradlewFile = searchDir.appendingPathComponent("gradlew")
      let gradlewExists = FileManager.default.fileExists(atPath: gradlewFile.path)
      guard gradlewExists else {
        searchDir = searchDir.deletingLastPathComponent()
        continue
      }

      let gradlewBatFile = searchDir.appendingPathComponent("gradlew.bat")
      let gradlewBatExists = FileManager.default.fileExists(atPath: gradlewBatFile.path)

      let gradleDir = searchDir.appendingPathComponent("gradle")
      let gradleDirExists = FileManager.default.fileExists(atPath: gradleDir.path)
      guard gradleDirExists else {
        searchDir = searchDir.deletingLastPathComponent()
        continue
      }

      try? FileManager.default.copyItem(
        at: gradlewFile,
        to: resolverWorkDirectory.appendingPathComponent("gradlew")
      )
      if gradlewBatExists {
        try? FileManager.default.copyItem(
          at: gradlewBatFile,
          to: resolverWorkDirectory.appendingPathComponent("gradlew.bat")
        )
      }
      try? FileManager.default.copyItem(
        at: gradleDir,
        to: resolverWorkDirectory.appendingPathComponent("gradle")
      )
      return
    }
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Errors

public enum JavaDependencyResolverError: Error, CustomStringConvertible {
  case noDependencies
  case gradleFailed(message: String)

  public var description: String {
    switch self {
    case .noDependencies:
      return "No dependencies specified in swift-java.config"
    case .gradleFailed(let message):
      return message
    }
  }
}
