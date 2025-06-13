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

import ArgumentParser
import Foundation
import SwiftJavaLib
import JExtractSwiftLib
import JavaKit
import JavaKitJar
import JavaKitNetwork
import JavaKitReflection
import SwiftSyntax
import SwiftSyntaxBuilder
import JavaKitConfigurationShared
import JavaKitShared

protocol SwiftJavaBaseAsyncParsableCommand: AsyncParsableCommand {
  var logLevel: Logger.Level { get set }

  var commonOptions: SwiftJava.CommonOptions { get set }

  var effectiveSwiftModule: String { get }

  mutating func runSwiftJavaCommand(config: inout Configuration) async throws

}

extension SwiftJavaBaseAsyncParsableCommand {
  public mutating func run() async {
    print("[info][swift-java] Run: \(CommandLine.arguments.joined(separator: " "))")
    print("[info][swift-java] Current work directory: \(URL(fileURLWithPath: "."))")

    do {
      var config = try readInitialConfiguration(command: self)
      try await runSwiftJavaCommand(config: &config)
    } catch {
      // We fail like this since throwing out of the run often ends up hiding the failure reason when it is executed as SwiftPM plugin (!)
      let message = "Failed with error: \(error)"
      print("[error][java-swift] \(message)")
      fatalError(message)
    }

    // Just for debugging so it is clear which command has finished
    print("[debug][swift-java] " + "Done: ".green + CommandLine.arguments.joined(separator: " ").green)
  }
}

extension SwiftJavaBaseAsyncParsableCommand {
  mutating func writeContents(
    _ contents: String,
    to filename: String, description: String) throws {
    try writeContents(
      contents,
      outputDirectoryOverride: self.actualOutputDirectory,
      to: filename,
      description: description)
  }

  mutating func writeContents(
    _ contents: String,
    outputDirectoryOverride: Foundation.URL?,
    to filename: String,
    description: String) throws {
    guard let outputDir = (outputDirectoryOverride ?? actualOutputDirectory) else {
      print("// \(filename) - \(description)")
      print(contents)
      return
    }

    // If we haven't tried to create the output directory yet, do so now before
    // we write any files to it.
    // if !createdOutputDirectory {
    try FileManager.default.createDirectory(
      at: outputDir,
      withIntermediateDirectories: true
    )
    // createdOutputDirectory = true
    //}

    // Write the file:
    let file = outputDir.appendingPathComponent(filename)
    print("[debug][swift-java] Writing \(description) to '\(file.path)'... ", terminator: "")
    try contents.write(to: file, atomically: true, encoding: .utf8)
    print("done.".green)
  }
}


extension SwiftJavaBaseAsyncParsableCommand {
  var logLevel: Logger.Level {
    get {
      self.commonOptions.logLevel
    }
    set {
    self.commonOptions.logLevel = newValue
    }
  }
}
extension SwiftJavaBaseAsyncParsableCommand {

  var moduleBaseDir: Foundation.URL? {
//    if let outputDirectory = commonOptions.outputDirectory {
//      if outputDirectory == "-" {
//        return nil
//      }
//
//      print("[debug][swift-java] Module base directory based on outputDirectory!")
//      return URL(fileURLWithPath: outputDirectory)
//    }

//    guard let swiftModule else {
//      return nil
//    }

    // Put the result into Sources/\(swiftModule).
    let baseDir = URL(fileURLWithPath: ".")
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent(self.effectiveSwiftModule, isDirectory: true)

    return baseDir
  }

  /// The output directory in which to place the generated files, which will
  /// be the specified directory (--output-directory or -o option) if given,
  /// or a default directory derived from the other command-line arguments.
  ///
  /// Returns `nil` only when we should emit the files to standard output.
  var actualOutputDirectory: Foundation.URL? {
    if let outputDirectory = commonOptions.outputDirectory {
      if outputDirectory == "-" {
        return nil
      }

      return URL(fileURLWithPath: outputDirectory)
    }

    // Put the result into Sources/\(swiftModule).
    let baseDir = URL(fileURLWithPath: ".")
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent(effectiveSwiftModule, isDirectory: true)

    // For generated Swift sources, put them into a "generated" subdirectory.
    // The configuration file goes at the top level.
    let outputDir: Foundation.URL
      //    if jar {
            // precondition(self.input != nil, "-jar mode requires path to jar to be specified as input path")
      outputDir = baseDir
      //    } else {
      //      outputDir = baseDir
      //        .appendingPathComponent("generated", isDirectory: true)
      //    }

    return outputDir
  }

  func readInitialConfiguration(command: some SwiftJavaBaseAsyncParsableCommand) throws -> Configuration {
    var earlyConfig: Configuration?
    if let moduleBaseDir {
      print("[debug][swift-java] Load config from module base directory: \(moduleBaseDir.path)")
      earlyConfig = try readConfiguration(sourceDir: moduleBaseDir.path)
    } else if let inputSwift = commonOptions.inputSwift {
      print("[debug][swift-java] Load config from module swift input directory: \(inputSwift)")
      earlyConfig = try readConfiguration(sourceDir: inputSwift)
    }
    var config = earlyConfig ?? Configuration()
    // override configuration with options from command line
    config.logLevel = command.logLevel
    return config
  }
}