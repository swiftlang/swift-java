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
import Java2SwiftLib
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
struct JavaToSwift: ParsableCommand {
  static var _commandName: String { "Java2Swift" }

  @Option(help: "The name of the Swift module into which the resulting Swift types will be generated.")
  var moduleName: String?

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

  @Option(name: .shortAndLong, help: "The directory in which to output the generated Swift files or the Java2Swift configuration file.")
  var outputDirectory: String? = nil

  
  @Option(name: .shortAndLong, help: "Directory where to write cached values (e.g. swift-java.classpath files)")
  var cacheDirectory: String? = nil
  
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
    help:
      "The input file, which is either a Java2Swift configuration file or (if '-jar' was specified) a Jar file."
  )
  var input: String

  /// Whether we have ensured that the output directory exists.
  var createdOutputDirectory: Bool = false

  var moduleBaseDir: Foundation.URL? {
      if let outputDirectory {
        if outputDirectory == "-" {
          return nil
        }

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
    case classWrappers // (Configuration)

    /// Fetch dependencies for a module
    case fetchDependencies // (Configuration)
    // FIXME each mode should have its own config?
  }

  mutating func run() {
    print("[info][swift-java] Run: \(CommandLine.arguments.joined(separator: " "))")
    do {
      let config: Configuration
      
      // Determine the mode in which we'll execute.
      let toolMode: ToolMode
      if jar {
        if let moduleBaseDir {
          config = try readConfiguration(sourceDir: moduleBaseDir.path)
        } else {
          config = Configuration()
        }
        toolMode = .configuration(extraClasspath: input)
      } else if fetch {
        config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
        guard let dependencies = config.dependencies else {
          print("[swift-java] Running in 'fetch dependencies' mode but dependencies list was empty!")
          print("[swift-java] Nothing to do: done.")
          return
        }
        toolMode = .fetchDependencies
      } else {
        config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
        toolMode = .classWrappers
      }

      let moduleName = self.moduleName ??
        input.split(separator: "/").dropLast().last.map(String.init) ??
        "__UnknownModule"

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
        if let dependencyResolverClasspath = fetchDependenciesCachedClasspath() {
          print("[debug][swift-java] Found cached dependency resolver classpath: \(dependencyResolverClasspath)")
          classpathEntries += dependencyResolverClasspath
        }
      case .classWrappers:
        break;
      }

      // Add extra classpath entries which are specific to building the JavaKit project and samples
      let classpathBuildJavaKitEntries = [ // FIXME: THIS IS A TRICK UNTIL WE FIGURE OUT HOW TO BOOTSTRAP THIS PART
        FileManager.default.currentDirectoryPath,
        FileManager.default.currentDirectoryPath + "/.build",
        FileManager.default.currentDirectoryPath + "/JavaKit/build/libs",
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
          .deletingLastPathComponent()
          .deletingLastPathComponent().absoluteURL.path + "/JavaKit/build/libs/JavaKit-1.0-SNAPSHOT.jar"
      ]
      classpathEntries += classpathBuildJavaKitEntries
    
      // Bring up the Java VM.
      // TODO: print only in verbose mode
      let classpath = classpathEntries.joined(separator: ":")
      print("[debug][swift-java] Initialize JVM with classpath: \(classpath)")

      let jvm = try JavaVirtualMachine.shared(classpath: classpathEntries)

      // FIXME: we should resolve dependencies here perhaps
  //    if let dependencies = config.dependencies {
  //      print("[info][swift-java] Resolve dependencies...")
  //      let dependencyClasspath = try fetchDependencies(
  //        moduleName: moduleName,
  //        dependencies: dependencies,
  //        baseClasspath: classpathOptionEntries,
  //        environment: jvm.environment()
  //      )
  //      classpathEntries += dependencyClasspath.classpathEntries
  //    }

      //   * Classespaths from all dependent configuration files
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
        guard let moduleName = self.moduleName else {
          fatalError("Fetching dependencies must specify module name (--module-name)!")
        }
        guard let effectiveCacheDirectory else {
          fatalError("Fetching dependencies must effective cache directory! Specify --output-directory or --cache-directory")
        }

        print("[debug][swift-java] Base classpath to fetch dependencies: \(classpathOptionEntries)")

        let dependencyClasspath = try fetchDependencies(
          moduleName: moduleName,
          dependencies: dependencies,
          baseClasspath: classpathOptionEntries,
          environment: jvm.environment()
        )

        try writeFetchedDependenciesClasspath(
          moduleName: moduleName,
          cacheDir: effectiveCacheDirectory,
          resolvedClasspath: dependencyClasspath)
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

extension JavaToSwift {
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
      return (true, try readConfiguration(sourceDir: configPath.path))
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

