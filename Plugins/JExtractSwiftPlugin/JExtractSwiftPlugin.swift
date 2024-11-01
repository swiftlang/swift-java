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
struct JExtractSwiftBuildToolPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let sourceModule = target.sourceModule else { return [] }

    // Note: Target doesn't have a directoryURL counterpart to directory,
    // so we cannot eliminate this deprecation warning.
    let sourceDir = target.directory.string

    let configuration = try readConfiguration(sourceDir: "\(sourceDir)")

    // We use the the usual maven-style structure of "src/[generated|main|test]/java/..."
    // that is common in JVM ecosystem
    let outputDirectoryJava = context.pluginWorkDirectoryURL
      .appending(path: "src")
      .appending(path: "generated")
      .appending(path: "java")
    let outputDirectorySwift = context.pluginWorkDirectoryURL

    var arguments: [String] = [
      "--swift-module", sourceModule.name,
      "--package-name", configuration.javaPackage,
      "--output-directory-java", outputDirectoryJava.path(percentEncoded: false),
      "--output-directory-swift", outputDirectorySwift.path(percentEncoded: false),
      // TODO: "--build-cache-directory", ...
      //       Since plugins cannot depend on libraries we cannot detect what the output files will be,
      //       as it depends on the contents of the input files. Therefore we have to implement this as a prebuild plugin.
      //       We'll have to make up some caching inside the tool so we don't re-parse files which have not changed etc.
    ]
    arguments.append(sourceDir)

    return [
      .prebuildCommand(
        displayName: "Generate Java wrappers for Swift types",
        executable: try context.tool(named: "JExtractSwiftTool").url,
        arguments: arguments,
        // inputFiles: [ configFile ] + swiftFiles,
        // outputFiles: outputJavaFiles
        outputFilesDirectory: outputDirectorySwift
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
