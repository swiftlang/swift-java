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
final class JExtractSwiftCommandPlugin: SwiftJavaPluginProtocol, BuildToolPlugin, CommandPlugin {

  var pluginName: String = "swift-java-command"
  var verbose: Bool = getEnvironmentBool("SWIFT_JAVA_VERBOSE")

  /// Build the target before attempting to extract from it.
  /// This avoids trying to extract from broken sources.
  ///
  /// You may disable this if confident that input targets sources are correct and there's no need to kick off a pre-build for some reason.
  var buildInputs: Bool = true

  /// Build the target once swift-java sources have been generated.
  /// This helps verify that the generated output is correct, and won't miscompile on the next build.
  var buildOutputs: Bool = true

  func createBuildCommands(context: PluginContext, target: any Target) async throws -> [Command] {
    // FIXME: This is not a build plugin but SwiftPM forces us to impleme the protocol anyway? rdar://139556637
    return []
  }

  func performCommand(context: PluginContext, arguments: [String]) throws {
    // Plugin can't have dependencies, so we have some naive argument parsing instead:
    self.verbose = arguments.contains("-v") || arguments.contains("--verbose")

    for target in context.package.targets {
      guard getSwiftJavaConfigPath(target: target) != nil else {
        log("[swift-java-command] Skipping jextract step: Missing swift-java.config for target '\(target.name)'")
        continue
      }

      do {
        let extraArguments = arguments.filter { arg in
          arg != "-v" && arg != "--verbose"
        }
        print("[swift-java-command] Extracting Java wrappers from target: '\(target.name)'...")
        try performCommand(context: context, target: target, extraArguments: extraArguments)
      } catch {
        print("[swift-java-command] error: Failed to extract from target '\(target.name)': \(error)")
      }

      print("[swift-java-command] Done.")
    }
    print("[swift-java-command] Generating sources: " + "done".green + ".")
  }

  func prepareJExtractArguments(context: PluginContext, target: Target) throws -> [String] {
    guard let sourceModule = target.sourceModule else { return [] }

    // Note: Target doesn't have a directoryURL counterpart to directory,
    // so we cannot eliminate this deprecation warning.
    let sourceDir = target.directory.string

    let configuration = try readConfiguration(sourceDir: "\(sourceDir)")

    var arguments: [String] = [
      /*subcommand=*/"jextract",
      "--input-swift", sourceDir,
      "--swift-module", sourceModule.name,
      "--output-java", context.outputJavaDirectory.path(percentEncoded: false),
      "--output-swift", context.outputSwiftDirectory.path(percentEncoded: false),
      // TODO: "--build-cache-directory", ...
      //       Since plugins cannot depend on libraries we cannot detect what the output files will be,
      //       as it depends on the contents of the input files. Therefore we have to implement this as a prebuild plugin.
      //       We'll have to make up some caching inside the tool so we don't re-parse files which have not changed etc.
    ]
    if let package = configuration?.javaPackage, !package.isEmpty {
      arguments += ["--java-package", package]
    }

    return arguments
  }

  /// Perform the command on a specific target.
  func performCommand(context: PluginContext, target: Target, extraArguments: [String]) throws {
    guard let sourceModule = target.sourceModule else { return }

    if self.buildInputs {
      // Make sure the target can builds properly
      log("Pre-building target '\(target.name)' before extracting sources...")
      let targetBuildResult = try self.packageManager.build(.target(target.name), parameters: .init())

      guard targetBuildResult.succeeded else {
        print("[swift-java-command] Build of '\(target.name)' failed: \(targetBuildResult.logText)")
        return
      }
    }

    let arguments = try prepareJExtractArguments(context: context, target: target)

    try runExtract(context: context, target: target, arguments: arguments + extraArguments)

    if self.buildOutputs {
      // Building the *products* since we need to build the dylib that contains our newly generated sources,
      // so just building the target again would not be enough. We build all products which we affected using
      // our source generation, which usually would be just a product dylib with our library.
      //
      // In practice, we'll always want to build after generating; either here,
      // or via some other task before we run any Java code, calling into Swift.
      log("Post-extract building products with target '\(target.name)'...")
      for product in context.package.products where product.targets.contains(where: { $0.id == target.id }) {
        log("Post-extract building product '\(product.name)'...")
        let buildResult = try self.packageManager.build(.product(product.name), parameters: .init())
        
        if buildResult.succeeded {
          log("Post-extract build: " + "done".green + ".")
        } else {
          log("Post-extract build: " + "done".red + "!")
        }
      }
    }
  }

  func runExtract(context: PluginContext, target: Target, arguments: [String]) throws {
    let process = Process()
    process.executableURL = try context.tool(named: "SwiftJavaTool").url
    process.arguments = arguments

    do {
      log("Execute: \(process.executableURL!.absoluteURL.relativePath) \(arguments.joined(separator: " "))")

      try process.run()
      process.waitUntilExit()

      assert(process.terminationStatus == 0, "Process failed with exit code: \(process.terminationStatus)")
    } catch {
      print("[swift-java-command] Failed to extract Java sources for target: '\(target.name); Error: \(error)")
    }
  }

}

// Mini coloring helper, since we cannot have dependencies we keep it minimal here
extension String {
  var red: String {
    "\u{001B}[0;31m" + "\(self)" + "\u{001B}[0;0m"
  }
  var green: String {
    "\u{001B}[0;32m" + "\(self)" + "\u{001B}[0;0m"
  }
}

