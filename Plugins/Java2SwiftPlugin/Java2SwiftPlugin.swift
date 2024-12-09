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

  var pluginName: String = "swift-java"
  var verbose: Bool = getEnvironmentBool("SWIFT_JAVA_VERBOSE")
  
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    log("Create build commands for target '\(target.name)'")
    guard let sourceModule = target.sourceModule else { return [] }

    let executable = try context.tool(named: "Java2Swift").url
    var commands: [Command] = []
    
    // Note: Target doesn't have a directoryURL counterpart to directory,
    // so we cannot eliminate this deprecation warning.
    let sourceDir = target.directory.string

    // The name of the configuration file JavaKit.config from the target for
    // which we are generating Swift wrappers for Java classes.
    let configFile = URL(filePath: sourceDir)
      .appending(path: SwiftJavaConfigFileName)
    let config = try readConfiguration(sourceDir: sourceDir)

    log("Config on path: \(configFile.path(percentEncoded: false))")
    log("Config was: \(config)")
    var javaDependencies = config.dependencies ?? []

    /// Find the manifest files from other Java2Swift executions in any targets
    /// this target depends on.
    var dependentConfigFiles: [(String, URL)] = []
    func searchForConfigFiles(in target: any Target) {
      // log("Search for config files in target: \(target.name)")
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
        // log("Dependency target: \(target.name)")
        searchForConfigFiles(in: target)

      case .product(let product):
        // log("Dependency product: \(product.name)")
        for target in product.targets {
          // log("Dependency product: \(product.name), target: \(target.name)")
          searchForConfigFiles(in: target)
        }

      @unknown default:
        break
      }
    }

    // Process indirect target dependencies.
    for dependency in target.recursiveTargetDependencies {
      // log("Recursive dependency target: \(dependency.name)")
      searchForConfigFiles(in: dependency)
    }

    var arguments: [String] = []
    arguments += argumentsModuleName(sourceModule: sourceModule)
    arguments += argumentsOutputDirectory(context: context)
    
    arguments += dependentConfigFiles.flatMap { moduleAndConfigFile in
      let (moduleName, configFile) = moduleAndConfigFile
      return [
        "--depends-on",
        "\(moduleName)=\(configFile.path(percentEncoded: false))"
      ]
    }
    arguments.append(configFile.path(percentEncoded: false))

//    guard let classes = config.classes else {
//      log("Config at \(configFile) did not have 'classes' configured, skipping java2swift step.")
//      return []
//    }
    let classes = config.classes ?? [:]
    print("Classes to wrap: \(classes.map(\.key))")

    /// Determine the set of Swift files that will be emitted by the Java2Swift tool.
    // TODO: this is not precise and won't work with more advanced Java files, e.g. lambdas etc.
    let outputDirectoryGenerated = self.outputDirectory(context: context, generated: true)
    let outputSwiftFiles = classes.map { (javaClassName, swiftName) in
      let swiftNestedName = swiftName.replacingOccurrences(of: ".", with: "+")
      return outputDirectoryGenerated.appending(path: "\(swiftNestedName).swift")
    }
    
    arguments += [
      "--cache-directory",
      context.pluginWorkDirectoryURL.path(percentEncoded: false)
    ]

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
      arguments += ["--classpath", classpath.path()]

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
        arguments += ["--swift-native-implementation", className]
      }
    }
    
    var fetchDependenciesOutputFiles: [URL] = []
    if let dependencies = config.dependencies, !dependencies.isEmpty {
      let displayName = "Fetch (Java) dependencies for Swift target \(sourceModule.name)"
      log("Prepared: \(displayName)")
      
      fetchDependenciesOutputFiles += [
        outputFilePath(context: context, generated: false, filename: "\(sourceModule.name).swift-java.classpath")
      ]
      
      commands += [
        .buildCommand(
          displayName: displayName,
          executable: executable,
          arguments: [
            "--fetch", configFile.path(percentEncoded: false),
            "--module-name", sourceModule.name,
            "--output-directory", outputDirectory(context: context, generated: false).path(percentEncoded: false)
          ],
          environment: [:],
          inputFiles: [configFile],
          outputFiles: fetchDependenciesOutputFiles
        )
      ]
    } else {
      log("No dependencies to fetch for target \(sourceModule.name)")
    }
    
    if !outputSwiftFiles.isEmpty {
      commands += [
        .buildCommand(
          displayName: "Wrapping \(classes.count) Java classes in Swift target '\(sourceModule.name)'",
          executable: executable,
          arguments: arguments,
          inputFiles: compiledClassFiles + fetchDependenciesOutputFiles + [
            configFile
          ],
          outputFiles: outputSwiftFiles
        )
      ]
    } else {
      log("No Swift output files, skip wrapping")
    }
    
    return commands
  }
}

extension Java2SwiftBuildToolPlugin {
  func argumentsModuleName(sourceModule: Target) -> [String] {
    return [
      "--module-name", sourceModule.name
    ]
  }
  
  func argumentsOutputDirectory(context: PluginContext, generated: Bool = true) -> [String] {
    return [
      "--output-directory",
      outputDirectory(context: context, generated: generated).path(percentEncoded: false)
    ]
  }
  
  func outputDirectory(context: PluginContext, generated: Bool = true) -> URL {
    let dir = context.pluginWorkDirectoryURL
    if generated {
      return dir.appending(path: "generated")
    } else {
      return dir
    }
  }
  
  func outputFilePath(context: PluginContext, generated: Bool, filename: String) -> URL {
    outputDirectory(context: context, generated: generated).appending(path: filename)
  }
}
