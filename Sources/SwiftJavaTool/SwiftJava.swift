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

/// Command-line utility to drive the export of Java classes into Swift types.
@main
struct SwiftJava: AsyncParsableCommand {
  static var _commandName: String { "swift-java" }

  @Option(help: "The name of the Swift module into which the resulting Swift types will be generated.")
  var moduleName: String? // TODO: rename to --swift-module?

  @Option(
    help:
      "A Java2Swift configuration file for a given Swift module name on which this module depends, e.g., JavaKitJar=Sources/JavaKitJar/Java2Swift.config. There should be one of these options for each Swift module that this module depends on (transitively) that contains wrapped Java sources."
  )
  var dependsOn: [String] = []

  // TODO: This should be a "make wrappers" option that just detects when we give it a jar
  @Flag(
    help:
      "Specifies that the input is a Jar file whose public classes will be loaded. The output of Java2Swift will be a configuration file (Java2Swift.config) that can be used as input to a subsequent Java2Swift invocation to generate wrappers for those public classes."
  )
  var jar: Bool = false

  @Flag(help: "Fetch dependencies from given target (containing swift-java configuration) or dependency string")
  var fetch: Bool = false

  @Option(
    name: [.customLong("cp"), .customLong("classpath")],
    help: "Class search path of directories and zip/jar files from which Java classes can be loaded."
  )
  var classpath: [String] = []

  @Option(
    help: "The names of Java classes whose declared native methods will be implemented in Swift."
  )
  var swiftNativeImplementation: [String] = []

  @Option(help: "Directory containing Swift files which should be extracted into Java bindings. Also known as 'jextract' mode. Must be paired with --output-java and --output-swift.")
  var inputSwift: String? = nil

  @Option(help: "The directory where generated Swift files should be written. Generally used with jextract mode.")
  var outputSwift: String? = nil

  @Option(help: "The directory where generated Java files should be written. Generally used with jextract mode.")
  var outputJava: String? = nil

  @Option(help: "The Java package the generated Java code should be emitted into.")
  var javaPackage: String? = nil

  // TODO: clarify this vs outputSwift (history: outputSwift is jextract, and this was java2swift)
  @Option(name: .shortAndLong, help: "The directory in which to output the generated Swift files or the SwiftJava configuration file.")
  var outputDirectory: String? = nil

  @Option(name: .shortAndLong, help: "Directory where to write cached values (e.g. swift-java.classpath files)")
  var cacheDirectory: String? = nil

  @Option(name: .shortAndLong, help: "Configure the level of logs that should be printed")
  var logLevel: Logger.Level = .info

  var effectiveCacheDirectory: String? {
    if let cacheDirectory {
      return cacheDirectory
    } else if let outputDirectory {
      return outputDirectory
    } else {
      return nil
    }
  }
  
  @Option(name: .shortAndLong, help: "How to handle an existing swift-java.config; by default 'overwrite' by can be changed to amending a configuration")
  var existingConfig: ExistingConfigFileMode = .overwrite
  public enum ExistingConfigFileMode: String, ExpressibleByArgument, Codable {
    case overwrite
    case amend
  }

  @Option(name: .shortAndLong, help: "While scanning a classpath, inspect only types included in this package")
  var javaPackageFilter: String? = nil

  @Argument(
    help: "The input file, which is either a Java2Swift configuration file or (if '-jar' was specified) a Jar file."
  )
  var input: String?

  /// Whether we have ensured that the output directory exists.
  var createdOutputDirectory: Bool = false

  var moduleBaseDir: Foundation.URL? {
      if let outputDirectory {
        if outputDirectory == "-" {
          return nil
        }

        print("[debug][swift-java] Module base directory based on outputDirectory!")
        return URL(fileURLWithPath: outputDirectory)
      }

      guard let moduleName else {
        return nil
      }

      // Put the result into Sources/\(moduleName).
      let baseDir = URL(fileURLWithPath: ".")
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent(moduleName, isDirectory: true)

      return baseDir
    }

  /// The output directory in which to place the generated files, which will
  /// be the specified directory (--output-directory or -o option) if given,
  /// or a default directory derived from the other command-line arguments.
  ///
  /// Returns `nil` only when we should emit the files to standard output.
  var actualOutputDirectory: Foundation.URL? {
    if let outputDirectory {
      if outputDirectory == "-" {
        return nil
      }

      return URL(fileURLWithPath: outputDirectory)
    }

    guard let moduleName else {
      fatalError("--module-name must be set!")
    }

    // Put the result into Sources/\(moduleName).
    let baseDir = URL(fileURLWithPath: ".")
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent(moduleName, isDirectory: true)

    // For generated Swift sources, put them into a "generated" subdirectory.
    // The configuration file goes at the top level.
    let outputDir: Foundation.URL
    if jar {
      precondition(self.input != nil, "-jar mode requires path to jar to be specified as input path")
      outputDir = baseDir
    } else {
      outputDir = baseDir
        .appendingPathComponent("generated", isDirectory: true)
    }

    return outputDir
  }

  /// Describes what kind of generation action is being performed by swift-java.
  enum ToolMode {
    /// Generate a configuration file given a Jar file.
    case configuration(extraClasspath: String) // FIXME: this is more like "extract" configuration from classpath

    /// Generate Swift wrappers for Java classes based on the given
    /// configuration.
    case classWrappers

    /// Fetch dependencies for a module
    case fetchDependencies

    /// Extract Java bindings from provided Swift sources.
    case jextract // TODO: carry jextract specific config here?
  }

  mutating func run() async {
    guard CommandLine.arguments.count > 1 else {
      // there's no "default" command, print USAGE when no arguments/parameters are passed.
      print("Must specify run mode.\n\(Self.helpMessage())")
      return
    }

    print("[info][swift-java] Run: \(CommandLine.arguments.joined(separator: " "))")
    print("[info][swift-java] Current work directory: \(URL(fileURLWithPath: "."))")
    print("[info][swift-java] Module base directory: \(moduleBaseDir)")
    do {
      var earlyConfig: Configuration?
      if let moduleBaseDir {
        print("[debug][swift-java] Load config from module base directory: \(moduleBaseDir.path)")
        earlyConfig = try readConfiguration(sourceDir: moduleBaseDir.path)
      } else if let inputSwift {
        print("[debug][swift-java] Load config from module swift input directory: \(inputSwift)")
        earlyConfig = try readConfiguration(sourceDir: inputSwift)
      }
      var config = earlyConfig ?? Configuration()

      config.logLevel = self.logLevel
      if let javaPackage {
        config.javaPackage = javaPackage
      }

      // Determine the mode in which we'll execute.
      let toolMode: ToolMode
      // TODO: some options are exclusive to each other so we should detect that
      if let inputSwift {
        guard let outputSwift else {
          print("[swift-java] --input-swift enabled 'jextract' mode, however no --output-swift directory was provided!\n\(Self.helpMessage())")
          return
        }
        guard let outputJava else {
          print("[swift-java] --input-swift enabled 'jextract' mode, however no --output-java directory was provided!\n\(Self.helpMessage())")
          return
        }
        config.swiftModule = self.moduleName // FIXME: rename the moduleName
        config.inputSwiftDirectory = self.inputSwift
        config.outputSwiftDirectory = self.outputSwift
        config.outputJavaDirectory = self.outputJava

        toolMode = .jextract
      } else if jar {
        guard let input else {
          fatalError("Mode -jar requires <input> path\n\(Self.helpMessage())")
        }
        toolMode = .configuration(extraClasspath: input)
      } else if fetch {
        guard let input else {
          fatalError("Mode 'fetch' requires <input> path\n\(Self.helpMessage())")
        }
        config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
        guard let dependencies = config.dependencies else {
          print("[swift-java] Running in 'fetch dependencies' mode but dependencies list was empty!")
          print("[swift-java] Nothing to do: done.")
          return
        }
        toolMode = .fetchDependencies
      } else {
        guard let input else {
          fatalError("Mode -jar requires <input> path\n\(Self.helpMessage())")
        }
        config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
        toolMode = .classWrappers
      }

      print("[debug][swift-java] Running swift-java in mode: " + "\(toolMode.prettyName)".bold)

      let moduleName: String =
        if let name = self.moduleName {
          name
        } else if let input {
          input.split(separator: "/").dropLast().last.map(String.init) ?? "__UnknownModule"
        } else {
          "__UnknownModule"
        }

      // Load all of the dependent configurations and associate them with Swift
      // modules.
      let dependentConfigs = try dependsOn.map { dependentConfig in
        guard let equalLoc = dependentConfig.firstIndex(of: "=") else {
          throw JavaToSwiftError.badConfigOption(dependentConfig)
        }

        let afterEqual = dependentConfig.index(after: equalLoc)
        let swiftModuleName = String(dependentConfig[..<equalLoc])
        let configFileName = String(dependentConfig[afterEqual...])

        let config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: configFileName))

        return (swiftModuleName, config)
      }

      // Form a class path from all of our input sources:
      //   * Command-line option --classpath
      let classpathOptionEntries: [String] = classpath.flatMap { $0.split(separator: ":").map(String.init) }
      let classpathFromEnv = ProcessInfo.processInfo.environment["CLASSPATH"]?.split(separator: ":").map(String.init) ?? []
      let classpathFromConfig: [String] = config.classpath?.split(separator: ":").map(String.init) ?? []
      print("[debug][swift-java] Base classpath from config: \(classpathFromConfig)")
      
      var classpathEntries: [String] = classpathFromConfig
      
      let swiftJavaCachedModuleClasspath = findSwiftJavaClasspaths(
        in: self.effectiveCacheDirectory ?? FileManager.default.currentDirectoryPath)
      print("[debug][swift-java] Classpath from *.swift-java.classpath files: \(swiftJavaCachedModuleClasspath)")
      classpathEntries += swiftJavaCachedModuleClasspath
      
      if !classpathOptionEntries.isEmpty {
        print("[debug][swift-java] Classpath from options: \(classpathOptionEntries)")
        classpathEntries += classpathOptionEntries
      } else {
        // * Base classpath from CLASSPATH env variable
        print("[debug][swift-java] Classpath from environment: \(classpathFromEnv)")
        classpathEntries += classpathFromEnv
      }

      switch toolMode {
      case .configuration(let extraClasspath):
        //   * Jar file (in `-jar` mode)
        let extraClasspathEntries = extraClasspath.split(separator: ":").map(String.init)
        print("[debug][swift-java] Extra classpath: \(extraClasspathEntries)")
        classpathEntries += extraClasspathEntries
      case .fetchDependencies:
        // if we have already fetched dependencies for the dependency loader,
        // let's use them so we can in-process resolve rather than forking a new
        // gradle process.
        print("[debug][swift-java] Add classpath from .classpath files")
        classpathEntries += findSwiftJavaClasspaths(in: FileManager.default.currentDirectoryPath)
//        if let dependencyResolverClasspath = fetchDependenciesCachedClasspath() {
//          print("[debug][swift-java] Found cached dependency resolver classpath: \(dependencyResolverClasspath)")
//          classpathEntries += dependencyResolverClasspath
//        }
      case .classWrappers, .jextract:
        break;
      }

      // Bring up the Java VM when necessary
      // TODO: print only in verbose mode
      let classpath = classpathEntries.joined(separator: ":")

      let jvm: JavaVirtualMachine!
      switch toolMode {
        case .configuration, .classWrappers:
          print("[debug][swift-java] Initialize JVM with classpath: \(classpath)")
          jvm = try JavaVirtualMachine.shared(classpath: classpathEntries)
        default:
          jvm = nil
      }

      //   * Classpaths from all dependent configuration files
      for (_, config) in dependentConfigs {
        // TODO: may need to resolve the dependent configs rather than just get their configs
        // TODO: We should cache the resolved classpaths as well so we don't do it many times
        config.classpath.map { entry in
          print("[swift-java] Add dependent config classpath element: \(entry)")
          classpathEntries.append(entry)
        }
      }

      // Run the task.
      switch toolMode {
      case .configuration:
        try emitConfiguration(
          classpath: classpath,
          environment: jvm.environment()
        )

      case .classWrappers/*(let config)*/:
        try generateWrappers(
          config: config,
          classpath: classpath,
          dependentConfigs: dependentConfigs,
          environment: jvm.environment()
        )

      case .fetchDependencies:
        guard let dependencies = config.dependencies else {
          fatalError("Configuration for fetching dependencies must have 'dependencies' defined!")
        }
        guard let effectiveCacheDirectory else {
          fatalError("Fetching dependencies must effective cache directory! Specify --output-directory or --cache-directory")
        }

        print("[debug][swift-java] Base classpath to fetch dependencies: \(classpathOptionEntries)")

        let dependencyClasspath = try await fetchDependencies(
          moduleName: moduleName,
          dependencies: dependencies
        )

        try writeFetchedDependenciesClasspath(
          moduleName: moduleName,
          cacheDir: effectiveCacheDirectory,
          resolvedClasspath: dependencyClasspath)

        case .jextract:
          try jextractSwift(config: config)
      }
    } catch {
      // We fail like this since throwing out of the run often ends up hiding the failure reason when it is executed as SwiftPM plugin (!)
      let message = "Failed with error: \(error)"
      print("[error][java-swift] \(message)")
      fatalError(message)
    }

    // Just for debugging so it is clear which command has finished
    print("[debug][swift-java] " + "Done: ".green + CommandLine.arguments.joined(separator: " ").green)
  }

  private func names(from javaClassNameOpt: String) -> (javaClassName: String, swiftName: String) {
    let javaClassName: String
    let swiftName: String
    if let equalLoc = javaClassNameOpt.firstIndex(of: "=") {
      let afterEqual = javaClassNameOpt.index(after: equalLoc)
      javaClassName = String(javaClassNameOpt[..<equalLoc])
      swiftName = String(javaClassNameOpt[afterEqual...])
    } else {
      if let dotLoc = javaClassNameOpt.lastIndex(of: ".") {
        let afterDot = javaClassNameOpt.index(after: dotLoc)
        swiftName = String(javaClassNameOpt[afterDot...])
      } else {
        swiftName = javaClassNameOpt
      }

      javaClassName = javaClassNameOpt
    }

    return (javaClassName, swiftName.javaClassNameToCanonicalName)
  }

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
    if !createdOutputDirectory {
      try FileManager.default.createDirectory(
        at: outputDir,
        withIntermediateDirectories: true
      )
      createdOutputDirectory = true
    }

    // Write the file:
    let file = outputDir.appendingPathComponent(filename)
    print("[debug][swift-java] Writing \(description) to '\(file.path)'... ", terminator: "")
    try contents.write(to: file, atomically: true, encoding: .utf8)
    print("done.".green)
  }
}

extension SwiftJava {
  /// Get base configuration, depending on if we are to 'amend' or 'overwrite' the existing configuration.
  package func getBaseConfigurationForWrite() throws -> (Bool, Configuration) {
    guard let actualOutputDirectory = self.actualOutputDirectory else {
      // If output has no path there's nothing to amend
      return (false, .init())
    }

    switch self.existingConfig {
    case .overwrite:
      // always make up a fresh instance if we're overwriting
      return (false, .init())
    case .amend:
      let configPath = actualOutputDirectory
      guard let config = try readConfiguration(sourceDir: configPath.path) else {
        return (false, .init())
      }
      return (true, config)
    }
  }
}

enum JavaToSwiftError: Error {
  case badConfigOption(String)
}

extension JavaToSwiftError: CustomStringConvertible {
  var description: String {
    switch self {
    case .badConfigOption(_):
      "configuration option must be of the form '<swift module name>=<path to config file>"
    }
  }
}

@JavaClass("java.lang.ClassLoader")
public struct ClassLoader {
  @JavaMethod
  public func loadClass(_ arg0: String) throws -> JavaClass<JavaObject>?
}

extension JavaClass<ClassLoader> {
  @JavaStaticMethod
  public func getSystemClassLoader() -> ClassLoader?
}

extension SwiftJava.ToolMode {
  var prettyName: String {
    switch self {
      case .configuration: "Configuration"
      case .fetchDependencies: "Fetch dependencies"
      case .classWrappers: "Wrap Java classes"
      case .jextract: "JExtract Swift for Java"
    }
  }
}
