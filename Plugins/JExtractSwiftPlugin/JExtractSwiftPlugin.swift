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
struct JExtractSwiftBuildToolPlugin: SwiftJavaPluginProtocol, BuildToolPlugin {

  var pluginName: String = "swift-java"
  var verbose: Bool = getEnvironmentBool("SWIFT_JAVA_VERBOSE")

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let toolURL = try context.tool(named: "SwiftJavaTool").url
    
    guard let sourceModule = target.sourceModule else { return [] }

    // Note: Target doesn't have a directoryURL counterpart to directory,
    // so we cannot eliminate this deprecation warning.
    for dependency in target.dependencies {
      switch (dependency) {
      case .target(let t):
        t.sourceModule
      case .product(let p):
        p.sourceModules
      @unknown default:
        fatalError("Unknown target dependency type: \(dependency)")
      }
    }

    let sourceDir = target.directory.string

    // The name of the configuration file SwiftJava.config from the target for
    // which we are generating Swift wrappers for Java classes.
    let configFile = URL(filePath: sourceDir).appending(path: "swift-java.config")
    let configuration = try readConfiguration(sourceDir: "\(sourceDir)")
    
    guard let javaPackage = configuration?.javaPackage else {
      // throw SwiftJavaPluginError.missingConfiguration(sourceDir: "\(sourceDir)", key: "javaPackage")
      log("Skipping jextract step, no 'javaPackage' configuration in \(getSwiftJavaConfigPath(target: target) ?? "")")
      return []
    }

    // We use the the usual maven-style structure of "src/[generated|main|test]/java/..."
    // that is common in JVM ecosystem
    let outputJavaDirectory = context.outputJavaDirectory
    let outputSwiftDirectory = context.outputSwiftDirectory

    let dependentConfigFiles = searchForDependentConfigFiles(in: target)

    var arguments: [String] = [
      /*subcommand=*/"jextract",
      "--swift-module", sourceModule.name,
      "--input-swift", sourceDir,
      "--output-java", outputJavaDirectory.path(percentEncoded: false),
      "--output-swift", outputSwiftDirectory.path(percentEncoded: false),
      // since SwiftPM requires all "expected" files do end up being written
      // and we don't know which files will have actual thunks generated... we force jextract to write even empty files.
      "--write-empty-files",
      // TODO: "--build-cache-directory", ...
      //       Since plugins cannot depend on libraries we cannot detect what the output files will be,
      //       as it depends on the contents of the input files. Therefore we have to implement this as a prebuild plugin.
      //       We'll have to make up some caching inside the tool so we don't re-parse files which have not changed etc.
    ]

    let dependentConfigFilesArguments = dependentConfigFiles.flatMap { moduleAndConfigFile in
      let (moduleName, configFile) = moduleAndConfigFile
      return [
        "--depends-on",
        "\(configFile.path(percentEncoded: false))"
      ]
    }
    arguments += dependentConfigFilesArguments

    if !javaPackage.isEmpty {
      arguments += ["--java-package", javaPackage]
    }

    let swiftFiles = sourceModule.sourceFiles.map { $0.url }.filter {
      $0.pathExtension == "swift"
    }

    var outputSwiftFiles: [URL] = swiftFiles.compactMap { sourceFileURL in
      guard sourceFileURL.isFileURL else {
        return nil as URL?
      }

      let sourceFilePath = sourceFileURL.path
      guard sourceFilePath.starts(with: sourceDir) else {
        fatalError("Could not get relative path for source file \(sourceFilePath)")
      }
      var outputURL = outputSwiftDirectory
        .appending(path: String(sourceFilePath.dropFirst(sourceDir.count).dropLast(sourceFileURL.lastPathComponent.count + 1)))

      let inputFileName = sourceFileURL.deletingPathExtension().lastPathComponent
      return outputURL.appending(path: "\(inputFileName)+SwiftJava.swift")
    }

    // Append the "module file" that contains any thunks for global func definitions
    outputSwiftFiles += [
      outputSwiftDirectory.appending(path: "\(sourceModule.name)Module+SwiftJava.swift")
    ]

    // If the module uses 'Data' type, the thunk file is emitted as if 'Data' is declared
    // in that module. Declare the thunk file as the output.
    // FIXME: Make this conditional.
    outputSwiftFiles += [
      outputSwiftDirectory.appending(path: "Data+SwiftJava.swift")
    ]

    return [
      .buildCommand(
        displayName: "Generate Java wrappers for Swift types",
        executable: toolURL,
        arguments: arguments,
        inputFiles: [ configFile ] + swiftFiles,
        outputFiles: outputSwiftFiles
      )
    ]
  }

  /// Find the manifest files from other swift-java executions in any targets
  /// this target depends on.
  func searchForDependentConfigFiles(in target: any Target) -> [(String, URL)] {
    var dependentConfigFiles = [(String, URL)]()

    func _searchForConfigFiles(in target: any Target) {
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
        _searchForConfigFiles(in: target)

      case .product(let product):
        // log("Dependency product: \(product.name)")
        for target in product.targets {
          // log("Dependency product: \(product.name), target: \(target.name)")
          _searchForConfigFiles(in: target)
        }

      @unknown default:
        break
      }
    }

    // Process indirect target dependencies.
    for dependency in target.recursiveTargetDependencies {
      // log("Recursive dependency target: \(dependency.name)")
      _searchForConfigFiles(in: dependency)
    }

    return dependentConfigFiles
  }
}

