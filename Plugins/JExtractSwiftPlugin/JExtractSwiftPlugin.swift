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

    var arguments: [String] = [
      "--input-swift", sourceDir,
      "--swift-module", sourceModule.name,
      "--output-java", outputJavaDirectory.path(percentEncoded: false),
      "--output-swift", outputSwiftDirectory.path(percentEncoded: false),
      // TODO: "--build-cache-directory", ...
      //       Since plugins cannot depend on libraries we cannot detect what the output files will be,
      //       as it depends on the contents of the input files. Therefore we have to implement this as a prebuild plugin.
      //       We'll have to make up some caching inside the tool so we don't re-parse files which have not changed etc.
    ]
    // arguments.append(sourceDir)
    if !javaPackage.isEmpty {
      arguments.append(contentsOf: ["--java-package", javaPackage])
    }

    return [
      .prebuildCommand(
        displayName: "Generate Java wrappers for Swift types",
        executable: toolURL,
        arguments: arguments,
        // inputFiles: [ configFile ] + swiftFiles,
        // outputFiles: outputJavaFiles
        outputFilesDirectory: outputSwiftDirectory
      )
    ]
  }
}

