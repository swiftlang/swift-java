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
@testable import SwiftJavaConfigurationShared
@testable import SwiftJavaTool // test in terminal, if xcode can't find the module
import Testing

@Suite(.serialized)
class JavaRepositoryTests {
  static let localRepo: String = {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftJavaTest-Local-Repo", isDirectory: true)
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.path
  }()

  static let localJarRepo: String = {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftJavaTest-Local-Repo-Jar-Only", isDirectory: true)
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.path
  }()

  static let localPomRepo: String = {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SwiftJavaTest-Local-Repo-Pom-Only", isDirectory: true)
    try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory.path
  }()

  deinit {
    for item in [Self.localRepo, Self.localJarRepo, Self.localPomRepo] {
      try? FileManager.default.removeItem(atPath: item)
    }
  }

  @Test(arguments: Configuration.resolvableConfigurations)
  func resolvableDependency(configuration: SwiftJavaConfigurationShared.Configuration) async throws {
    try await resolve(configuration: configuration)
  }

  @Test
  func nonResolvableDependency() async throws {
    try await #expect(processExitsWith: .failure, "commonCSVWithUnknownDependencies") {
      try await resolve(configuration: .commonCSVWithUnknownDependencies)
    }
    try await #expect(processExitsWith: .failure, "jitpackJsonUsingCentralRepository") {
      try await resolve(configuration: .jitpackJsonUsingCentralRepository)
    }
    try await #expect(processExitsWith: .failure, "jitpackJsonInRepoIncludeIOOnly") {
      try await resolve(configuration: .jitpackJsonInRepoIncludeIOOnly)
    }
    try await #expect(processExitsWith: .failure, "andriodCoreInCentral") {
      try await resolve(configuration: .andriodCoreInCentral)
    }
    try await #expect(processExitsWith: .failure, "androidLifecycleInRepo") {
      try await resolve(configuration: .androidLifecycleInRepo)
    }
  }

  @Test
  func respositoryDecoding() throws {
    let data = """
      [
        { "type": "maven", "url": "https://repo.mycompany.com/maven2" },
        {
          "type": "maven",
          "url": "https://repo2.mycompany.com/maven2",
          "artifactUrls": [
            "https://repo.mycompany.com/jars",
            "https://repo.mycompany.com/jars2"
          ]
        },
        { "type": "maven", "url": "https://secure.repo.com/maven2" },
        { "type": "mavenLocal", "includeGroups": ["com.example.myproject"] },
        { "type": "maven", "url": "build/repo" },
        { "type": "mavenCentral" },
        { "type": "mavenLocal" },
        { "type": "google" }
      ]
      """.data(using: .utf8)!
    let repositories = try JSONDecoder().decode([JavaRepositoryDescriptor].self, from: data)
    #expect(!repositories.isEmpty, "Expected to decode at least one repository")
    #expect(repositories.contains(.maven(url: "https://repo.mycompany.com/maven2")), "Expected to contain the default repository")
    #expect(repositories.contains(.maven(url: "build/repo")), "Expected to contain a repository from a build repo")
    #expect(repositories.contains(.maven(url: "https://repo2.mycompany.com/maven2", artifactUrls: ["https://repo.mycompany.com/jars", "https://repo.mycompany.com/jars2"])), "Expected to contain a repository with artifact URLs")
    #expect(repositories.contains(.mavenLocal(includeGroups: ["com.example.myproject"])), "Expected to contain mavenLocal with includeGroups")
    #expect(repositories.contains(.mavenLocal()), "Expected to contain mavenLocal")
    #expect(repositories.contains(.other("mavenCentral")), "Expected to contain mavenCentral")
    #expect(repositories.contains(.other("google")), "Expected to contain google")
  }
}

// Wired issue with #require, marking the function as static seems to resolve it
private func resolve(configuration: SwiftJavaConfigurationShared.Configuration) async throws {
  var config = configuration
  var command = try SwiftJava.ResolveCommand.parse([
    "--output-directory",
    ".build/\(configuration.swiftModule!)/destination/SwiftJavaPlugin/",

    "--swift-module",
    configuration.swiftModule!
  ])
  try await config.downloadIfNeeded()
  try await command.runSwiftJavaCommand(config: &config)
}

extension SwiftJavaConfigurationShared.Configuration {
  static var resolvableConfigurations: [Configuration] = [
    .commonCSV, .jitpackJson,
    .jitpackJsonInRepo,
    andriodCoreInGoogle
  ]

  static let commonCSV: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaCommonCSV"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.apache.commons", artifactID: "commons-csv", version: "1.12.0")
    ]
    return configuration
  }()

  static let jitpackJson: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaJson"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.andrejs", artifactID: "json", version: "1.2")
    ]
    configuration.repositories = [.maven(url: "https://jitpack.io")]
    return configuration
  }()

  static let jitpackJsonInRepo: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaJson"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.andrejs", artifactID: "json", version: "1.2")
    ]
    // using the following property to download to local repo
    configuration.packageToDownload = #""org.andrejs:json:1.2""#
    configuration.remoteRepo = "https://jitpack.io"

    let repo = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".m2/repository")
    configuration.repositories = [.maven(url: repo.path)]
    return configuration
  }()

  static let androidLifecycleInRepoWithCustomArtifacts: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaAndroidLifecycle"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "android.arch.lifecycle", artifactID: "common", version: "1.1.1")
    ]
    // using the following property to download to local repo
    configuration.packageToDownload = #""android.arch.lifecycle:common:1.1.1""#
    configuration.remoteRepo = "https://maven.google.com"
    configuration.splitPackage = true

    configuration.repositories = [
      .maven(url: JavaRepositoryTests.localJarRepo, artifactUrls: [
        JavaRepositoryTests.localPomRepo
      ])
    ]
    return configuration
  }()

  static let andriodCoreInGoogle: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaAndroidCommon"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "android.arch.core", artifactID: "common", version: "1.1.1")
    ]
    configuration.repositories = [.other("google")] // google()
    return configuration
  }()

  // MARK: - Non resolvable dependencies

  static let commonCSVWithUnknownDependencies: Configuration = {
    var configuration = Configuration.commonCSV
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.apache.commons.unknown", artifactID: "commons-csv", version: "1.12.0")
    ]
    return configuration
  }()

  static let jitpackJsonInRepoIncludeIOOnly: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaJson"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.andrejs", artifactID: "json", version: "1.2")
    ]
    // using the following property to download to local repo
    configuration.packageToDownload = #""org.andrejs:json:1.2""#
    configuration.remoteRepo = "https://jitpack.io"
    // use local repo, since includeGroups only applied to mavenLocal
    configuration.preferredLocalRepo = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".m2/repository").path

    configuration.repositories = [.mavenLocal(includeGroups: ["commons-io"])]
    return configuration
  }()

  static let jitpackJsonUsingCentralRepository: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaJson"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.andrejs", artifactID: "json", version: "1.2")
    ]
    return configuration
  }()

  static let andriodCoreInCentral: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaAndroidCommon"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "android.arch.core", artifactID: "common", version: "1.1.1")
    ]
    return configuration
  }()

  static let androidLifecycleInRepo: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaAndroidLifecycle"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "android.arch.lifecycle", artifactID: "common", version: "1.1.1")
    ]
    // using the following property to download to local repo
    configuration.packageToDownload = #""android.arch.lifecycle:common:1.1.1""#
    configuration.remoteRepo = "https://maven.google.com"
    configuration.splitPackage = true

    configuration.repositories = [
      .maven(url: JavaRepositoryTests.localJarRepo/*, artifactUrls: [
        JavaRepositoryTests.localPomRepo
      ]*/)
    ]
    return configuration
  }()
}

// MARK: - Download to local repo

private extension SwiftJavaConfigurationShared.Configuration {
  /// in json format, which means string needs to be quoted
  var packageToDownload: String? {
    get { javaPackage }
    set { javaPackage = newValue }
  }

  var remoteRepo: String? {
    get { outputJavaDirectory }
    set { outputJavaDirectory = newValue }
  }

  /// whether to download jar and pom files separately
  var splitPackage: Bool? {
    get { writeEmptyFiles }
    set { writeEmptyFiles = newValue }
  }

  var preferredLocalRepo: String? {
    get { classpath }
    set { classpath = newValue }
  }

  func downloadIfNeeded() async throws {
    guard
      let data = packageToDownload?.data(using: .utf8),
      let descriptor = try? JSONDecoder().decode(JavaDependencyDescriptor.self, from: data),
      let repo = remoteRepo
    else {
      return
    }
    let splitPackage = splitPackage ?? false

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = [
      "mvn", "dependency:get",
      "-DremoteRepositories=\(repo)",
      "-DgroupId=\(descriptor.groupID)",
      "-DartifactId=\(descriptor.artifactID)",
      "-Dversion=\(descriptor.version)",
      "-q"
    ]

    if splitPackage {
      print("Downloading: \(descriptor) from \(repo) to \(JavaRepositoryTests.localJarRepo) and \(JavaRepositoryTests.localPomRepo)".yellow)
      process.arguments?.append(contentsOf: [
        "-Dpackaging=jar",
        "-Dmaven.repo.local=\(JavaRepositoryTests.localJarRepo)",
        "&&",
        "mvn", "dependency:get",
        "-DremoteRepositories=\(repo)",
        "-DgroupId=\(descriptor.groupID)",
        "-DartifactId=\(descriptor.artifactID)",
        "-Dversion=\(descriptor.version)",
        "-Dpackaging=pom",
        "-Dmaven.repo.local=\(JavaRepositoryTests.localPomRepo)",
        "-q"
      ])
    } else {
      let repoPath = classpath ?? JavaRepositoryTests.localRepo
      print("Downloading: \(descriptor) from \(repo) to \(repoPath)".yellow)
      process.arguments?.append("-Dmaven.repo.local=\(repoPath)")
    }

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
      print("Download complete: \(descriptor)".green)
    } else {
      throw NSError(
        domain: "DownloadError",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "Unzip failed with status \(process.terminationStatus)"]
      )
    }
  }
}
