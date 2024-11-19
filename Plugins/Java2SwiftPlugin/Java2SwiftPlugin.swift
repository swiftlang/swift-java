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

fileprivate let SwiftJavaConfigFileName = "swift-java.config"

@main
struct Java2SwiftBuildToolPlugin: SwiftJavaPluginProtocol, BuildToolPlugin {

  var pluginName: String = "swift-java-javac"
  var verbose: Bool = getEnvironmentBool("SWIFT_JAVA_VERBOSE")
  
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let sourceModule = target.sourceModule else { return [] }

    // Note: Target doesn't have a directoryURL counterpart to directory,
    // so we cannot eliminate this deprecation warning.
    let sourceDir = target.directory.string

    // The name of the configuration file JavaKit.config from the target for
    // which we are generating Swift wrappers for Java classes.
    let configFile = URL(filePath: sourceDir)
      .appending(path: SwiftJavaConfigFileName)
    let configData = try Data(contentsOf: configFile)
    let config = try JSONDecoder().decode(Configuration.self, from: configData)

    /// Find the manifest files from other Java2Swift executions in any targets
    /// this target depends on.
    var dependentConfigFiles: [(String, URL)] = []
    func searchForConfigFiles(in target: any Target) {
      let dependencyURL = URL(filePath: target.directory.string)

      // Look for a config file within this target.
      let dependencyConfigURL = dependencyURL
        .appending(path: SwiftJavaConfigFileName)
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

    guard let classes = config.classes else {
      log("Config at \(configFile) did not have 'classes' configured, skipping java2swift step.")
      return []
    }
    
    /// Determine the set of Swift files that will be emitted by the Java2Swift
    /// tool.
    let outputSwiftFiles = classes.map { (javaClassName, swiftName) in
      let swiftNestedName = swiftName.replacingOccurrences(of: ".", with: "+")
      return outputDirectory.appending(path: "\(swiftNestedName).swift")
    }

    // Find the Java .class files generated from prior plugins.
    let compiledClassFiles = sourceModule.pluginGeneratedResources.filter { url in
      url.pathExtension == "class"
    }

    if let firstClassFile = compiledClassFiles.first {
      // Keep stripping off parts of the path until we hit the "Java" part.
      // That's where the class path starts.
      var classpath = firstClassFile
      while classpath.lastPathComponent != "Java" {
        classpath.deleteLastPathComponent()
      }
      arguments += [ "--classpath", classpath.path() ]

      // For each of the class files, note that it can have Swift-native
      // implementations. We figure this out based on the path.
      for classFile in compiledClassFiles {
        var classFile = classFile.deletingPathExtension()
        var classNameComponents: [String] = []

        while classFile.lastPathComponent != "Java" {
          classNameComponents.append(classFile.lastPathComponent)
          classFile.deleteLastPathComponent()
        }

        let className = classNameComponents
          .reversed()
          .joined(separator: ".")
        arguments += [ "--swift-native-implementation", className]
      }
    }
    
    guard let classes = config.classes else {
      log("Skipping java2swift step: Missing 'classes' key in swift-java.config at '\(configFile.path)'")
      return []
    }

    return [
      .buildCommand(
        displayName: "Wrapping \(classes.count) Java classes target \(sourceModule.name) in Swift",
        executable: try context.tool(named: "Java2Swift").url,
        arguments: arguments,
        inputFiles: [ configFile ] + compiledClassFiles,
        outputFiles: outputSwiftFiles
      )
    ]
  }
}
