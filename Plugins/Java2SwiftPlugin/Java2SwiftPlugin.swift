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
import PackagePlugin

@main
struct Java2SwiftBuildToolPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let sourceModule = target.sourceModule else { return [] }

    // Note: Target doesn't have a directoryURL counterpart to directory,
    // so we cannot eliminate this deprecation warning.
    let sourceDir = target.directory.string

    // Read a configuration file JavaKit.config from the target that provides
    // information needed to call Java2Swift.
    let configFile = URL(filePath: sourceDir)
      .appending(path: "Java2Swift.config")
    let configData = try Data(contentsOf: configFile)
    let config = try JSONDecoder().decode(Configuration.self, from: configData)

    /// Find the manifest files from other Java2Swift executions in any targets
    /// this target depends on.
    var manifestFiles: [URL] = []
    func searchForManifestFiles(in target: any Target) {
      let dependencyURL = URL(filePath: target.directory.string)

      // Look for a checked-in manifest file.
      let generatedManifestURL = dependencyURL
        .appending(path: "generated")
        .appending(path: "\(target.name).swift2java")
      let generatedManifestString = generatedManifestURL
        .path(percentEncoded: false)

      if FileManager.default.fileExists(atPath: generatedManifestString) {
        manifestFiles.append(generatedManifestURL)
      }

      // TODO: Look for a manifest file that was built by the plugin itself.
    }

    // Process direct dependencies of this target.
    for dependency in target.dependencies {
      switch dependency {
      case .target(let target):
        searchForManifestFiles(in: target)

      case .product(let product):
        for target in product.targets {
          searchForManifestFiles(in: target)
        }

      @unknown default:
        break
      }
    }

    // Process indirect target dependencies.
    for dependency in target.recursiveTargetDependencies {
      searchForManifestFiles(in: dependency)
    }

    /// Determine the list of Java classes that will be translated into Swift,
    /// along with the names of the corresponding Swift types. This will be
    /// passed along to the Java2Swift tool.
    let classes = config.classes.sorted { (lhs, rhs) in
      lhs.0 < rhs.0
    }

    let outputDirectory = context.pluginWorkDirectoryURL
      .appending(path: "generated")

    var arguments: [String] = [
      "--module-name", sourceModule.name,
      "--output-directory", outputDirectory.path(percentEncoded: false),
    ]
    if let classPath = config.classPath {
      arguments += ["-cp", classPath]
    }
    arguments += manifestFiles.flatMap { manifestFile in
      [ "--manifests", manifestFile.path(percentEncoded: false) ]
    }
    arguments += classes.map { (javaClassName, swiftName) in
      "\(javaClassName)=\(swiftName)"
    }

    /// Determine the set of Swift files that will be emitted by the Java2Swift
    /// tool.
    let outputSwiftFiles = classes.map { (javaClassName, swiftName) in
      outputDirectory.appending(path: "\(swiftName).swift")
    } + [
      outputDirectory.appending(path: "\(sourceModule.name).swift2java")
    ]

    return [
      .buildCommand(
        displayName: "Wrapping \(classes.count) Java classes target \(sourceModule.name) in Swift",
        executable: try context.tool(named: "Java2Swift").url,
        arguments: arguments,
        inputFiles: [ configFile ],
        outputFiles: outputSwiftFiles
      )
    ]
  }
}

// Note: the JAVA_HOME environment variable must be set to point to where
// Java is installed, e.g.,
//   Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home.
func findJavaHome() -> String {
  if let home = ProcessInfo.processInfo.environment["JAVA_HOME"] {
    return home
  }

  // This is a workaround for envs (some IDEs) which have trouble with
  // picking up env variables during the build process
  let path = "\(FileManager.default.homeDirectoryForCurrentUser.path()).java_home"
  if let home = try? String(contentsOfFile: path, encoding: .utf8) {
    if let lastChar = home.last, lastChar.isNewline {
      return String(home.dropLast())
    }

    return home
  }

  fatalError("Please set the JAVA_HOME environment variable to point to where Java is installed.")
}
