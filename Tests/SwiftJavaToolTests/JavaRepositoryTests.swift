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
@testable import SwiftJavaTool // test in terminal with sandbox disabled, if xcode can't find the module
import Testing

@Suite(.serialized)
class JavaRepositoryTests {
  static let localRepo: String = String.localRepoRootDirectory.appending("/All")

  static let localJarRepo: String = String.localRepoRootDirectory.appending("/JarOnly")

  static let localPomRepo: String = String.localRepoRootDirectory.appending("/PomOnly")

  deinit {
    for item in [Self.localRepo, Self.localJarRepo, Self.localPomRepo] {
      try? FileManager.default.removeItem(atPath: item)
    }
  }

  @Test(arguments: Configuration.resolvableConfigurations)
  func resolvableDependency(configuration: SwiftJavaConfigurationShared.Configuration) async throws {
    try await resolve(configuration: configuration)
  }

  #if compiler(>=6.2)
  @Test
  func nonResolvableDependency() async throws {
    try await #expect(processExitsWith: .failure, "commonCSVWithUnknownDependencies") {
      try await resolve(configuration: .commonCSVWithUnknownDependencies)
    }
    try await #expect(processExitsWith: .failure, "helloWorldInLocalRepoIncludeIOOnly") {
      try await resolve(configuration: .helloWorldInLocalRepoIncludeIOOnly)
    }
    try await #expect(processExitsWith: .failure, "androidCoreInCentral") {
      try await resolve(configuration: .androidCoreInCentral)
    }
    try await #expect(processExitsWith: .failure, "helloWorldInRepoWithoutArtifact") {
      try await resolve(configuration: .helloWorldInRepoWithoutArtifact)
    }
  }
  #endif

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
    ".build/\(configuration.swiftModule!)/destination/SwiftJavaPlugin",

    "--swift-module",
    configuration.swiftModule!,
  ])
  try config.publishSampleJavaProjectIfNeeded()
  try await command.runSwiftJavaCommand(config: &config)
}

extension SwiftJavaConfigurationShared.Configuration {
  static var resolvableConfigurations: [Configuration] = [
    .commonCSV, .jitpackJson,
    .helloWorldInTempRepo,
    .helloWorldInLocalRepo,
    .helloWorldInRepoWithCustomArtifacts,
    .androidCoreInGoogle,
  ]

  /// Tests with Apache Commons CSV in mavenCentral
  static let commonCSV: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaCommonCSV"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.apache.commons", artifactID: "commons-csv", version: "1.12.0"),
    ]
    return configuration
  }()

  /// Tests with JSON library from Jitpack
  static let jitpackJson: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaJson"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.andrejs", artifactID: "json", version: "1.2"),
    ]
    configuration.repositories = [.maven(url: "https://jitpack.io")]
    return configuration
  }()

  /// Tests with local library HelloWorld published to temporary local maven repo
  static let helloWorldInTempRepo: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "HelloWorld"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "com.example", artifactID: "HelloWorld", version: "1.0.0"),
    ]
    configuration.packageToPublish = "SimpleJavaProject"

    configuration.repositories = [.maven(url: JavaRepositoryTests.localRepo)]
    return configuration
  }()
  
  /// Tests with local library HelloWorld published to user's local maven repo
  static let helloWorldInLocalRepo: Configuration = {
    var configuration = Configuration.helloWorldInTempRepo

    configuration.repositories = [.mavenLocal(includeGroups: ["com.example"])]
    return configuration
  }()

  /// Tests with local library HelloWorld published to temporary local maven repo, with custom artifact URLs
  static let helloWorldInRepoWithCustomArtifacts: Configuration = {
    var configuration = Configuration.helloWorldInTempRepo
    configuration.repositories = [
      .maven(url: JavaRepositoryTests.localPomRepo, artifactUrls: [
        JavaRepositoryTests.localJarRepo,
      ]),
    ]
    return configuration
  }()

  /// Tests with Android Core library in Google's Maven repository
  static let androidCoreInGoogle: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaAndroidCommon"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "android.arch.core", artifactID: "common", version: "1.1.1"),
    ]
    configuration.repositories = [.other("google")] // google()
    return configuration
  }()

  // MARK: - Non resolvable dependencies

  /// Tests with Apache Commons CSV in mavenCentral, but with an unknown dependency, it should fail
  static let commonCSVWithUnknownDependencies: Configuration = {
    var configuration = Configuration.commonCSV
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "org.apache.commons.unknown", artifactID: "commons-csv", version: "1.12.0"),
    ]
    return configuration
  }()

  /// Tests with local library HelloWorld published to user's local maven repo, but trying to include a group that doesn't match, it should fail
  static let helloWorldInLocalRepoIncludeIOOnly: Configuration = {
    var configuration = Configuration.helloWorldInLocalRepo
    configuration.repositories = [.mavenLocal(includeGroups: ["commons-io"])]
    return configuration
  }()

  /// Tests with Android Core library in mavenCentral, it should fail because it's only in Google's repo
  static let androidCoreInCentral: Configuration = {
    var configuration = Configuration()
    configuration.swiftModule = "JavaAndroidCommon"
    configuration.dependencies = [
      JavaDependencyDescriptor(groupID: "android.arch.core", artifactID: "common", version: "1.1.1"),
    ]
    return configuration
  }()

  /// Tests with local library HelloWorld published to temporary local maven repo, but without artifactUrls, it should fail
  static let helloWorldInRepoWithoutArtifact: Configuration = {
    var configuration = Configuration.helloWorldInTempRepo

    configuration.repositories = [
      .maven(url: JavaRepositoryTests.localJarRepo /* , artifactUrls: [
         JavaRepositoryTests.localPomRepo
       ] */ ),
    ]
    return configuration
  }()
}

// MARK: - Publish sample java project to local repo

private extension SwiftJavaConfigurationShared.Configuration {
  var packageToPublish: String? {
    get { javaPackage }
    set { javaPackage = newValue }
  }

  func publishSampleJavaProjectIfNeeded() throws {
    guard
      let packageName = packageToPublish
    else {
      return
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: .gradlewPath)
    process.arguments = [
      "-p", "\(String.packageDirectory)/Tests/SwiftJavaToolTests/\(packageName)",
      "publishAllArtifacts", 
      "publishToMavenLocal", // also publish to maven local to test includeGroups"
      "-q",
    ]

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
      print("Published \(packageName) to: \(String.localRepoRootDirectory)".green)
    } else {
      throw NSError(
        domain: "DownloadError",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "Unzip failed with status \(process.terminationStatus)"]
      )
    }
  }
}

private extension String {
  static var packageDirectory: Self {
    let path = getcwd(nil, 0)!
    // current directory where `swift test` is run, usually swift-java
    defer { free(path) }
    
    let dir = String(cString: path)
    // TODO: This needs to be tested in Xcode as well, for now Xcode can't run tests, due to this issue: https://github.com/swiftlang/swift-java/issues/281
    precondition(dir.hasSuffix("swift-java"), "Please run the tests from the swift-java directory")
    return dir
  }

  static var localRepoRootDirectory: Self {
    packageDirectory + "/.build/SwiftJavaToolTests/LocalRepo"
  }

  static var gradlewPath: Self {
    packageDirectory + "/gradlew"
  }
}
