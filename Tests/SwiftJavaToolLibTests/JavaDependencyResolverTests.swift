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
import SwiftJavaConfigurationShared
import SwiftJavaToolLib
import Testing

// ==== -----------------------------------------------------------------------
// MARK: TestFixtureError

enum TestFixtureError: Error, CustomStringConvertible {
  case gradlewNotFound(searchedFrom: String)
  case gradlePublishFailed(exitCode: Int32, output: String)

  var description: String {
    switch self {
    case .gradlewNotFound(let path):
      return "Could not find gradlew in parent directories of \(path)"
    case .gradlePublishFailed(let exitCode, let output):
      return "Gradle publish failed (exit code \(exitCode)): \(output)"
    }
  }
}

// ==== -----------------------------------------------------------------------
// MARK: JavaDependencyResolverTests

@Suite
struct JavaDependencyResolverTests {

  /// The path to the SimpleJavaProject test fixture.
  static var simpleJavaProjectDir: URL {
    let thisFile = URL(fileURLWithPath: #filePath)
    return thisFile.deletingLastPathComponent().appendingPathComponent("SimpleJavaProject")
  }

  /// Search parent directories for a `gradlew` wrapper script.
  private static func findGradlew(startingFrom directory: URL) throws -> URL {
    var searchDir = directory
    while searchDir.pathComponents.count > 1 {
      let candidate = searchDir.appendingPathComponent("gradlew")
      if FileManager.default.fileExists(atPath: candidate.path) {
        return candidate
      }
      searchDir = searchDir.deletingLastPathComponent()
    }
    throw TestFixtureError.gradlewNotFound(searchedFrom: directory.path)
  }

  /// Publish the SimpleJavaProject to a local maven repo.
  static func publishSampleJavaProject(to repoDir: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: repoDir.appendingPathComponent("com/example/hello-world/1.0.0").path) {
      return // Already published
    }

    try fm.createDirectory(at: repoDir, withIntermediateDirectories: true)

    let gradlew = try findGradlew(startingFrom: simpleJavaProjectDir)

    let process = Process()
    process.executableURL = gradlew
    process.arguments = [
      "--no-daemon",
      "-p", simpleJavaProjectDir.path,
      "publishMavenPublicationToLocalRepository",
      "-PrepoDir=\(repoDir.path)",
    ]
    process.currentDirectoryURL = simpleJavaProjectDir

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
      throw TestFixtureError.gradlePublishFailed(exitCode: process.terminationStatus, output: output)
    }
  }

  // ==== -------------------------------------------------------------------
  // MARK: Tests

  @Test(.tags(.slow, .gradle, .integration))
  func resolveFromLocalRepo() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-java-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let repoDir = tempDir.appendingPathComponent("local-repo")
    try Self.publishSampleJavaProject(to: repoDir)

    var config = Configuration()
    config.dependencies = [
      JavaDependencyDescriptor(groupID: "com.example", artifactID: "hello-world", version: "1.0.0")
    ]
    config.mavenRepositories = [
      .maven(url: repoDir.path)
    ]

    let workDir = tempDir.appendingPathComponent("work")
    try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

    let classpath = try await JavaDependencyResolver.resolve(config: config, workDir: workDir)
    #expect(!classpath.isEmpty, "Classpath should not be empty")
    #expect(
      classpath.contains("hello-world"),
      "Classpath should contain hello-world artifact, got: \(classpath)"
    )
  }

  @Test(.tags(.slow, .gradle, .integration))
  func resolveNonExistentDependency_fails() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-java-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let repoDir = tempDir.appendingPathComponent("local-repo")
    try Self.publishSampleJavaProject(to: repoDir)

    var config = Configuration()
    config.dependencies = [
      JavaDependencyDescriptor(groupID: "com.nonexistent", artifactID: "missing-lib", version: "1.0.0")
    ]
    // Only look in our local repo, should fail since com.nonexistent doesn't exist
    config.mavenRepositories = [
      .maven(url: repoDir.path)
    ]

    let workDir = tempDir.appendingPathComponent("work")
    try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

    await #expect(throws: JavaDependencyResolverError.self) {
      _ = try await JavaDependencyResolver.resolve(config: config, workDir: workDir)
    }
  }

  @Test(.tags(.slow, .gradle, .integration))
  func resolveFromLocalRepo_withIncludeGroupsFilter() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-java-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let repoDir = tempDir.appendingPathComponent("local-repo")
    try Self.publishSampleJavaProject(to: repoDir)

    var config = Configuration()
    config.dependencies = [
      JavaDependencyDescriptor(groupID: "com.example", artifactID: "hello-world", version: "1.0.0")
    ]
    config.mavenRepositories = [
      .maven(url: repoDir.path)
    ]

    let workDir = tempDir.appendingPathComponent("work")
    try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

    let classpath = try await JavaDependencyResolver.resolve(config: config, workDir: workDir)
    #expect(classpath.contains("hello-world"))
  }

  @Test
  func resolveNoDependencies_throws() async throws {
    let config = Configuration()
    let workDir = FileManager.default.temporaryDirectory

    await #expect(throws: JavaDependencyResolverError.self) {
      _ = try await JavaDependencyResolver.resolve(config: config, workDir: workDir)
    }
  }
}
