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

  @Flag(
    help:
      "Specifies that the input is a Jar file whose public classes will be loaded. The output of Java2Swift will be a configuration file (Java2Swift.config) that can be used as input to a subsequent Java2Swift invocation to generate wrappers for those public classes."
  )
  var jar: Bool = false

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

  @Argument(
    help:
      "The input file, which is either a Java2Swift configuration file or (if '-jar' was specified) a Jar file."
  )
  var input: String

  @Flag(help: "Fetch dependencies from given target (containing swift-java configuration) or dependency string")
  var fetch: Bool = false

  // TODO: Need a better name, this follows up a fetch with creating modules for each of the dependencies
  @Flag(help: "Fetch dependencies for given ")
  var fetchMakeModules: Bool = false

  /// Whether we have ensured that the output directory exists.
  var createdOutputDirectory: Bool = false

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
    case configuration(jarFile: String)

    /// Generate Swift wrappers for Java classes based on the given
    /// configuration.
    case classWrappers(Configuration)

    /// Fetch dependencies for a module
    case fetchDependencies(Configuration)
    // FIXME each mode should have its own config?
  }

  mutating func run() throws {
    // Determine the mode in which we'll execute.
    let toolMode: ToolMode
    if jar {
      toolMode = .configuration(jarFile: input)
    } else if fetch {
      let config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
      guard let dependencies = config.dependencies else {
        print("[swift-java] Running in 'fetch dependencies' mode but dependencies list was empty!")
        print("[swift-java] Nothing to do: done.")
        return
      }
      toolMode = .fetchDependencies(config)
    } else {
      let config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
      toolMode = .classWrappers(config)
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
    var classPathPieces: [String] = classpath.flatMap { $0.split(separator: ":").map(String.init) }
    switch toolMode {
    case .configuration(jarFile: let jarFile):
      //   * Jar file (in `-jar` mode)
      classPathPieces.append(jarFile)
    case .classWrappers(let config),
         .fetchDependencies(let config):
      //   * Classpath specified in the configuration file (if any)
      if let classpath = config.classPath {
        for part in classpath.split(separator: ":") {
          classPathPieces.append(String(part))
        }
      }
    }

    //   * Classespaths from all dependent configuration files
    for (_, config) in dependentConfigs {
      config.classPath.map { element in
        print("[swift-java] Add dependent config classpath element: \(element)")
        classPathPieces.append(element)
      }
    }

    // Bring up the Java VM.
    let classpath = classPathPieces.joined(separator: ":")
    // TODO: print only in verbose mode
    print("[swift-java] Initialize JVM with classpath: \(classpath)")


    // Run the task.
    let jvm: JavaVirtualMachine
    switch toolMode {
    case .configuration(jarFile: let jarFile):
      jvm = try JavaVirtualMachine.shared(classPath: classPathPieces)
      try emitConfiguration(
        forJarFile: jarFile,
        classPath: classpath,
        environment: jvm.environment()
      )

    case .classWrappers(let config):
      jvm = try JavaVirtualMachine.shared(classPath: classPathPieces)
      try generateWrappers(
        config: config,
        classPath: classpath,
        dependentConfigs: dependentConfigs,
        environment: jvm.environment()
      )

    case .fetchDependencies(let config):
      let dependencies = config.dependencies! // TODO: cleanup how we do config
      try fetchDependencies(moduleName: moduleName, dependencies: dependencies, baseClasspath: classPathPieces)
    }
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

  mutating func writeContents(_ contents: String, to filename: String, description: String) throws {
    guard let outputDir = actualOutputDirectory else {
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
    print("[swift-java] Writing \(description) to '\(file.path)'...", terminator: "")
    try contents.write(to: file, atomically: true, encoding: .utf8)
    print(" done.")
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

