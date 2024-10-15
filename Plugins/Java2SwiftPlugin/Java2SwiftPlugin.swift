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

fileprivate let Java2SwiftConfigFileName = "Java2Swift.config"

@main
struct Java2SwiftBuildToolPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let sourceModule = target.sourceModule else { return [] }

    // Note: Target doesn't have a directoryURL counterpart to directory,
    // so we cannot eliminate this deprecation warning.
    let sourceDir = target.directory.string

    // The name of the configuration file JavaKit.config from the target for
    // which we are generating Swift wrappers for Java classes.
    let configFile = URL(filePath: sourceDir)
      .appending(path: "Java2Swift.config")
    let configData = try Data(contentsOf: configFile)
    let config = try JSONDecoder().decode(Configuration.self, from: configData)

    /// Find the manifest files from other Java2Swift executions in any targets
    /// this target depends on.
    var dependentConfigFiles: [(String, URL)] = []
    func searchForConfigFiles(in target: any Target) {
      let dependencyURL = URL(filePath: target.directory.string)

      // Look for a config file within this target.
      let dependencyConfigURL = dependencyURL
        .appending(path: Java2SwiftConfigFileName)
      let dependencyConfigString = dependencyConfigURL
        .path(percentEncoded: false)

      if FileManager.default.fileExists(atPath: dependencyConfigString) {
        dependentConfigFiles.append((target.name, dependencyConfigURL))
      }
    }

    // Process direct dependencies of this target.
    for dependency in target.dependencies {
      switch dependency {
      case .target(let target):
        searchForConfigFiles(in: target)

      case .product(let product):
        for target in product.targets {
          searchForConfigFiles(in: target)
        }

      @unknown default:
        break
      }
    }

    // Process indirect target dependencies.
    for dependency in target.recursiveTargetDependencies {
      searchForConfigFiles(in: dependency)
    }

    let outputDirectory = context.pluginWorkDirectoryURL
      .appending(path: "generated")

    var arguments: [String] = [
      "--module-name", sourceModule.name,
      "--output-directory", outputDirectory.path(percentEncoded: false),
    ]
    arguments += dependentConfigFiles.flatMap { moduleAndConfigFile in
      let (moduleName, configFile) = moduleAndConfigFile
      return [
        "--depends-on",
        "\(moduleName)=\(configFile.path(percentEncoded: false))"
      ]
    }
    arguments.append(configFile.path(percentEncoded: false))

    /// Determine the set of Swift files that will be emitted by the Java2Swift
    /// tool.
    let outputSwiftFiles = config.classes.map { (javaClassName, swiftName) in
      outputDirectory.appending(path: "\(swiftName).swift")
    } + [
      outputDirectory.appending(path: "\(sourceModule.name).swift2java")
    ]

    return [
      .buildCommand(
        displayName: "Wrapping \(config.classes.count) Java classes target \(sourceModule.name) in Swift",
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
