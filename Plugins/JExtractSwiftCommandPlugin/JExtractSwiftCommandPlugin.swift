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
final class JExtractSwiftCommandPlugin: BuildToolPlugin, CommandPlugin {
  
  var verbose: Bool = false
  
  /// Build the target before attempting to extract from it.
  /// This avoids trying to extract from broken sources.
  ///
  /// You may disable this if confident that input targets sources are correct and there's no need to kick off a pre-build for some reason.
  var buildInputs: Bool = true
  
  /// Build the target once swift-java sources have been generated.
  /// This helps verify that the generated output is correct, and won't miscompile on the next build.
  var buildOutputs: Bool = true
  
  func createBuildCommands(context: PackagePlugin.PluginContext, target: any PackagePlugin.Target) async throws -> [PackagePlugin.Command] {
    // FIXME: This is not a build plugin but SwiftPM forces us to impleme the protocol anyway? rdar://139556637
    return []
  }
  
  func performCommand(context: PluginContext, arguments: [String]) throws {
    self.verbose = arguments.contains("-v") || arguments.contains("--verbose")
    
    let selectedTargets: [String] =
      if let last = arguments.lastIndex(where: { $0.starts(with: "-")}),
         last < arguments.endIndex {
        Array(arguments[..<last])
      } else {
        []
      }
    
    for target in context.package.targets {
      guard let configPath = getSwiftJavaConfig(target: target) else {
        log("Skipping target '\(target.name), has no 'swift-java.config' file")
        continue
      }
      
      do {
        print("[swift-java] Extracting Java wrappers from target: '\(target.name)'...")
        try performCommand(context: context, target: target, arguments: arguments)
      } catch {
        print("[swift-java] error: Failed to extract from target '\(target.name)': \(error)")
      }
    }
  }
  
  /// Perform the command on a specific target.
  func performCommand(context: PluginContext, target: Target, arguments: [String]) throws {
    // Make sure the target can builds properly
    try self.packageManager.build(.target(target.name), parameters: .init())
    
    guard let sourceModule = target.sourceModule else { return }

    if self.buildInputs {
      log("Pre-building target '\(target.name)' before extracting sources...")
      try self.packageManager.build(.target(target.name), parameters: .init())
    }
    
    if self.buildOutputs {
      log("Post-building target '\(target.name)' to verify generated sources...")
      try self.packageManager.build(.target(target.name), parameters: .init())
    }
    
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
      .appending(path: "src")
      .appending(path: "generated")
      .appending(path: "Sources")

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

    try runExtract(context: context, target: target, arguments: arguments)
  }
  
  func runExtract(context: PluginContext, target: Target, arguments: [String]) throws {
    let process = Process()
    process.executableURL = try context.tool(named: "JExtractSwiftTool").url
    process.arguments = arguments
    
    do {
      log("Execute: \(process.executableURL) \(arguments)")
      
      try process.run()
      process.waitUntilExit()
      
      assert(process.terminationStatus == 0, "Process failed with exit code: \(process.terminationStatus)")
    } catch {
      print("[swift-java][command] Failed to extract Java sources for target: '\(target.name); Error: \(error)")
    }
  }
  
  func log(_ message: @autoclosure () -> String) {
    if self.verbose {
      print("[swift-java] \(message())")
    }
  }
}
