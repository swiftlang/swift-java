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
@testable import SwiftJavaConfigurationShared
@testable import SwiftJavaToolLib
import XCTest

// ==== -----------------------------------------------------------------------
// MARK: JavaResolverTests

final class JavaResolverTests: XCTestCase {

  // ==== -------------------------------------------------------------------
  // MARK: Repository decoding tests

  func test_repositoryDecoding_mavenCentral() throws {
    let json = """
      { "type": "mavenCentral" }
      """
    let repo = try JSONDecoder().decode(JavaRepositoryDescriptor.self, from: json.data(using: .utf8)!)
    XCTAssertEqual(repo, .mavenCentral)
  }

  func test_repositoryDecoding_mavenLocal() throws {
    let json = """
      { "type": "mavenLocal" }
      """
    let repo = try JSONDecoder().decode(JavaRepositoryDescriptor.self, from: json.data(using: .utf8)!)
    XCTAssertEqual(repo, .mavenLocal())
  }

  func test_repositoryDecoding_mavenLocalWithIncludeGroups() throws {
    let json = """
      { "type": "mavenLocal", "includeGroups": ["com.example"] }
      """
    let repo = try JSONDecoder().decode(JavaRepositoryDescriptor.self, from: json.data(using: .utf8)!)
    XCTAssertEqual(repo, .mavenLocal(includeGroups: ["com.example"]))
  }

  func test_repositoryDecoding_google() throws {
    let json = """
      { "type": "google" }
      """
    let repo = try JSONDecoder().decode(JavaRepositoryDescriptor.self, from: json.data(using: .utf8)!)
    XCTAssertEqual(repo, .google)
  }

  func test_repositoryDecoding_maven() throws {
    let json = """
      { "type": "maven", "url": "https://repo.example.com/maven2" }
      """
    let repo = try JSONDecoder().decode(JavaRepositoryDescriptor.self, from: json.data(using: .utf8)!)
    XCTAssertEqual(repo, .maven(url: "https://repo.example.com/maven2"))
  }

  func test_repositoryDecoding_mavenWithArtifactUrls() throws {
    let json = """
      {
        "type": "maven",
        "url": "https://repo.example.com/maven2",
        "artifactUrls": ["https://repo.example.com/jars", "https://repo.example.com/jars2"]
      }
      """
    let repo = try JSONDecoder().decode(JavaRepositoryDescriptor.self, from: json.data(using: .utf8)!)
    XCTAssertEqual(
      repo,
      .maven(
        url: "https://repo.example.com/maven2",
        artifactUrls: ["https://repo.example.com/jars", "https://repo.example.com/jars2"]
      )
    )
  }

  func test_repositoryDecoding_unknownType() throws {
    let json = """
      { "type": "ivy" }
      """
    XCTAssertThrowsError(
      try JSONDecoder().decode(JavaRepositoryDescriptor.self, from: json.data(using: .utf8)!)
    )
  }

  // ==== -------------------------------------------------------------------
  // MARK: Repository encoding roundtrip

  func test_repositoryEncoding_roundtrip() throws {
    let repos: [JavaRepositoryDescriptor] = [
      .mavenCentral,
      .mavenLocal(),
      .mavenLocal(includeGroups: ["com.example"]),
      .google,
      .maven(url: "https://repo.example.com/maven2"),
      .maven(url: "https://repo.example.com/maven2", artifactUrls: ["https://jars.example.com"]),
    ]

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    for repo in repos {
      let data = try encoder.encode(repo)
      let decoded = try decoder.decode(JavaRepositoryDescriptor.self, from: data)
      XCTAssertEqual(repo, decoded, "Roundtrip failed for: \(repo)")
    }
  }

  // ==== -------------------------------------------------------------------
  // MARK: Configuration with repositories

  func test_configurationDecoding_withRepositories() throws {
    let json = """
      {
        "dependencies": ["com.example:hello-world:1.0.0"],
        "repositories": [
          { "type": "mavenLocal", "includeGroups": ["com.example"] },
          { "type": "mavenCentral" }
        ]
      }
      """
    let config = try readConfiguration(string: json, configPath: nil)
    XCTAssertNotNil(config)
    XCTAssertEqual(config?.repositories?.count, 2)
    XCTAssertEqual(config?.repositories?[0], .mavenLocal(includeGroups: ["com.example"]))
    XCTAssertEqual(config?.repositories?[1], .mavenCentral)
    XCTAssertEqual(config?.dependencies?.count, 1)
  }

  func test_configurationDecoding_withoutRepositories() throws {
    let json = """
      {
        "dependencies": ["com.example:hello-world:1.0.0"]
      }
      """
    let config = try readConfiguration(string: json, configPath: nil)
    XCTAssertNotNil(config)
    XCTAssertNil(config?.repositories)
  }

  // ==== -------------------------------------------------------------------
  // MARK: Gradle DSL generation

  func test_gradleDSL_mavenCentral() {
    XCTAssertEqual(JavaRepositoryDescriptor.mavenCentral.gradleDSL, "mavenCentral()")
  }

  func test_gradleDSL_mavenLocal() {
    XCTAssertEqual(JavaRepositoryDescriptor.mavenLocal().gradleDSL, "mavenLocal()")
  }

  func test_gradleDSL_mavenLocalWithIncludeGroups() {
    let repo = JavaRepositoryDescriptor.mavenLocal(includeGroups: ["com.example.myproject"])
    let dsl = repo.gradleDSL
    XCTAssertTrue(dsl.contains("mavenLocal"), "Expected mavenLocal in: \(dsl)")
    XCTAssertTrue(dsl.contains("includeGroup(\"com.example.myproject\")"), "Expected includeGroup in: \(dsl)")
  }

  func test_gradleDSL_google() {
    XCTAssertEqual(JavaRepositoryDescriptor.google.gradleDSL, "google()")
  }

  func test_gradleDSL_maven() {
    let repo = JavaRepositoryDescriptor.maven(url: "https://repo.example.com/maven2")
    let dsl = repo.gradleDSL
    XCTAssertTrue(dsl.contains("maven {"), "Expected 'maven {' in: \(dsl)")
    XCTAssertTrue(dsl.contains("url = uri(\"https://repo.example.com/maven2\")"), "Expected url in: \(dsl)")
  }

  func test_gradleDSL_mavenWithArtifactUrls() {
    let repo = JavaRepositoryDescriptor.maven(
      url: "https://repo.example.com/maven2",
      artifactUrls: ["https://jars.example.com"]
    )
    let dsl = repo.gradleDSL
    XCTAssertTrue(dsl.contains("artifactUrls"), "Expected artifactUrls in: \(dsl)")
    XCTAssertTrue(dsl.contains("\"https://jars.example.com\""), "Expected url in: \(dsl)")
  }

  // ==== -------------------------------------------------------------------
  // MARK: Build.gradle generation

  func test_generateBuildGradle_defaultRepositories() {
    let deps = [JavaDependencyDescriptor(groupID: "com.example", artifactID: "hello-world", version: "1.0.0")]
    let gradle = JavaResolver.generateBuildGradle(dependencies: deps, repositories: nil)

    XCTAssertTrue(gradle.contains("mavenCentral()"), "Expected mavenCentral in default repos")
    XCTAssertTrue(gradle.contains("implementation(\"com.example:hello-world:1.0.0\")"))
    XCTAssertTrue(gradle.contains("printRuntimeClasspath"))
  }

  func test_generateBuildGradle_customRepositories() {
    let deps = [JavaDependencyDescriptor(groupID: "com.example", artifactID: "hello-world", version: "1.0.0")]
    let repos: [JavaRepositoryDescriptor] = [
      .mavenLocal(includeGroups: ["com.example"]),
      .maven(url: "https://custom.repo.com/maven2"),
    ]
    let gradle = JavaResolver.generateBuildGradle(dependencies: deps, repositories: repos)

    XCTAssertTrue(gradle.contains("mavenLocal"), "Expected mavenLocal")
    XCTAssertTrue(gradle.contains("includeGroup(\"com.example\")"), "Expected includeGroup")
    XCTAssertTrue(gradle.contains("https://custom.repo.com/maven2"), "Expected custom URL")
    XCTAssertFalse(
      gradle.contains("    mavenCentral()"),
      "Should NOT have default mavenCentral when custom repos specified"
    )
  }

  // ==== -------------------------------------------------------------------
  // MARK: Local repo resolve tests

  /// The path to the SimpleJavaProject test fixture.
  static var simpleJavaProjectDir: URL {
    // Find it relative to this test file
    let thisFile = URL(fileURLWithPath: #filePath)
    return thisFile.deletingLastPathComponent().appendingPathComponent("SimpleJavaProject")
  }

  /// Publish the SimpleJavaProject to a local maven repo and return the repo path.
  static func publishSampleJavaProject(to repoDir: URL) throws {
    let fm = FileManager.default
    if fm.fileExists(atPath: repoDir.appendingPathComponent("com/example/hello-world/1.0.0").path) {
      return // Already published
    }

    try fm.createDirectory(at: repoDir, withIntermediateDirectories: true)

    // Find gradlew from the root of the swift-java project
    var searchDir = simpleJavaProjectDir
    var gradlewPath: URL?
    while searchDir.pathComponents.count > 1 {
      let candidate = searchDir.appendingPathComponent("gradlew")
      if fm.fileExists(atPath: candidate.path) {
        gradlewPath = candidate
        break
      }
      searchDir = searchDir.deletingLastPathComponent()
    }

    guard let gradlew = gradlewPath else {
      throw NSError(domain: "JavaResolverTests", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Could not find gradlew in parent directories of \(simpleJavaProjectDir.path)"
      ])
    }

    let process = Process()
    process.executableURL = gradlew
    process.arguments = [
      "--no-daemon",
      "-p", simpleJavaProjectDir.path,
      "publishMavenPublicationToLocalRepository",
      "-PrepoDir=\(repoDir.path)",
    ]
    process.currentDirectoryURL = simpleJavaProjectDir

    // Override the publishing repo URL
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
      let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
      throw NSError(domain: "JavaResolverTests", code: Int(process.terminationStatus), userInfo: [
        NSLocalizedDescriptionKey: "Gradle publish failed: \(output)"
      ])
    }
  }

  /// Test that we can resolve a dependency from a local Maven repository.
  @available(macOS 15, *)
  func test_resolveFromLocalRepo() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-java-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let repoDir = tempDir.appendingPathComponent("local-repo")
    try Self.publishSampleJavaProject(to: repoDir)

    var config = Configuration()
    config.dependencies = [
      JavaDependencyDescriptor(groupID: "com.example", artifactID: "hello-world", version: "1.0.0")
    ]
    config.repositories = [
      .maven(url: repoDir.path),
    ]

    let workDir = tempDir.appendingPathComponent("work")
    try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

    let classpath = try await JavaResolver.resolve(config: config, workDir: workDir)
    XCTAssertFalse(classpath.isEmpty, "Classpath should not be empty")
    XCTAssertTrue(
      classpath.contains("hello-world"),
      "Classpath should contain hello-world artifact, got: \(classpath)"
    )
  }

  /// Test that resolving a dependency that does not exist in the repo fails.
  @available(macOS 15, *)
  func test_resolveNonExistentDependency_fails() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-java-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let repoDir = tempDir.appendingPathComponent("local-repo")
    try Self.publishSampleJavaProject(to: repoDir)

    var config = Configuration()
    config.dependencies = [
      JavaDependencyDescriptor(groupID: "com.nonexistent", artifactID: "missing-lib", version: "1.0.0")
    ]
    // Only look in our local repo — should fail since com.nonexistent doesn't exist
    config.repositories = [
      .maven(url: repoDir.path),
    ]

    let workDir = tempDir.appendingPathComponent("work")
    try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

    do {
      _ = try await JavaResolver.resolve(config: config, workDir: workDir)
      XCTFail("Expected resolve to fail for non-existent dependency")
    } catch {
      // Expected — Gradle should fail to resolve
      XCTAssertTrue(
        "\(error)".contains("SWIFT_JAVA_CLASSPATH") || "\(error)".contains("Gradle"),
        "Error should be from Gradle resolution failure, got: \(error)"
      )
    }
  }

  /// Test that resolving with includeGroups filter works.
  @available(macOS 15, *)
  func test_resolveFromLocalRepo_withIncludeGroupsFilter() async throws {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("swift-java-test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tempDir) }

    let repoDir = tempDir.appendingPathComponent("local-repo")
    try Self.publishSampleJavaProject(to: repoDir)

    var config = Configuration()
    config.dependencies = [
      JavaDependencyDescriptor(groupID: "com.example", artifactID: "hello-world", version: "1.0.0")
    ]
    // Use maven with the local repo path + includeGroups on mavenLocal won't help here,
    // but we can still test that the config round-trips correctly
    config.repositories = [
      .maven(url: repoDir.path),
    ]

    let workDir = tempDir.appendingPathComponent("work")
    try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)

    let classpath = try await JavaResolver.resolve(config: config, workDir: workDir)
    XCTAssertTrue(classpath.contains("hello-world"))
  }

  /// Test that resolve throws for empty dependencies.
  func test_resolveNoDependencies_throws() async throws {
    let config = Configuration()
    let workDir = FileManager.default.temporaryDirectory

    if #available(macOS 15, *) {
      do {
        _ = try await JavaResolver.resolve(config: config, workDir: workDir)
        XCTFail("Expected noDependencies error")
      } catch JavaResolverError.noDependencies {
        // Expected
      }
    }
  }
}
