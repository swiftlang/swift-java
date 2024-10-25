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

/// Command-line utility to drive the export of Java classes into Swift types.
@main
struct JavaToSwift: ParsableCommand {
  static var _commandName: String { "Java2Swift" }

  @Option(help: "The name of the Swift module into which the resulting Swift types will be generated.")
  var moduleName: String

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

  /// Describes what kind of generation action is being performed by
  /// Java2Swift.
  enum GenerationMode {
    /// Generate a configuration file given a Jar file.
    case configuration(jarFile: String)

    /// Generate Swift wrappers for Java classes based on the given
    /// configuration.
    case classWrappers(Configuration)
  }

  mutating func run() throws {
    // Determine the mode in which we'll execute.
    let generationMode: GenerationMode
    if jar {
      generationMode = .configuration(jarFile: input)
    } else {
      let config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
      generationMode = .classWrappers(config)
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
    var classPathPieces: [String] = classpath
    switch generationMode {
    case .configuration(jarFile: let jarFile):
      //   * Jar file (in `-jar` mode)
      classPathPieces.append(jarFile)
    case .classWrappers(let config):
      //   * Class path specified in the configuration file (if any)
      config.classPath.map { classPathPieces.append($0) }
    }

    //   * Classes paths from all dependent configuration files
    for (_, config) in dependentConfigs {
      config.classPath.map { classPathPieces.append($0) }
    }

    // Bring up the Java VM.
    let jvm = try JavaVirtualMachine.shared(classPath: classPathPieces)

    // Run the generation step.
    let classPath = classPathPieces.joined(separator: ":")
    switch generationMode {
    case .configuration(jarFile: let jarFile):
      try emitConfiguration(
        forJarFile: jarFile,
        classPath: classPath,
        environment: jvm.environment()
      )

    case .classWrappers(let config):
      try generateWrappers(
        config: config,
        classPath: classPath,
        dependentConfigs: dependentConfigs,
        environment: jvm.environment()
      )
    }
  }

  /// Generate wrapper
  mutating func generateWrappers(
    config: Configuration,
    classPath: String,
    dependentConfigs: [(String, Configuration)],
    environment: JNIEnvironment
  ) throws {
    let translator = JavaTranslator(
      swiftModuleName: moduleName,
      environment: environment
    )

    // Keep track of all of the Java classes that will have
    // Swift-native implementations.
    translator.swiftNativeImplementations = Set(swiftNativeImplementation)

    // Note all of the dependent configurations.
    for (swiftModuleName, dependentConfig) in dependentConfigs {
      translator.addConfiguration(
        dependentConfig,
        forSwiftModule: swiftModuleName
      )
    }

    // Add the configuration for this module.
    translator.addConfiguration(config, forSwiftModule: moduleName)

    // Load all of the requested classes.
    #if false
    let classLoader = URLClassLoader(
      [
        try URL("file://\(classPath)", environment: environment)
      ],
      environment: environment
    )
    #else
    let classLoader = try JavaClass<ClassLoader>(environment: environment)
      .getSystemClassLoader()!
    #endif
    var javaClasses: [JavaClass<JavaObject>] = []
    for (javaClassName, swiftName) in config.classes {
      guard let javaClass = try classLoader.loadClass(javaClassName) else {
        print("warning: could not find Java class '\(javaClassName)'")
        continue
      }

      javaClasses.append(javaClass)

      // Replace any $'s within the Java class name (which separate nested
      // classes) with .'s (which represent nesting in Swift).
      let translatedSwiftName = swiftName.replacing("$", with: ".")

      // Note that we will be translating this Java class, so it is a known class.
      translator.translatedClasses[javaClassName] = (translatedSwiftName, nil, true)
    }

    // Translate all of the Java classes into Swift classes.
    for javaClass in javaClasses {
      translator.startNewFile()
      let swiftClassDecls = translator.translateClass(javaClass)
      let importDecls = translator.getImportDecls()

      let swiftFileText = """
        // Auto-generated by Java-to-Swift wrapper generator.
        \(importDecls.map { $0.description }.joined())
        \(swiftClassDecls.map { $0.description }.joined(separator: "\n"))

        """

      let swiftFileName = try! translator.getSwiftTypeName(javaClass).swiftName.replacing(".", with: "+") + ".swift"
      try writeContents(
        swiftFileText,
        to: swiftFileName,
        description: "Java class '\(javaClass.getCanonicalName())' translation"
      )
    }
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
    print("Writing \(description) to '\(file.path)'...", terminator: "")
    try contents.write(to: file, atomically: true, encoding: .utf8)
    print(" done.")
  }

  mutating func emitConfiguration(
    forJarFile jarFileName: String,
    classPath: String,
    environment: JNIEnvironment
  ) throws {
    var configuration = Configuration(classPath: classPath)

    let jarFile = try JarFile(jarFileName, false, environment: environment)
    for entry in jarFile.entries()! {
      // We only look at class files in the Jar file.
      guard entry.getName().hasSuffix(".class") else {
        continue
      }

      // If any of the segments of the Java name start with a number, it's a
      // local class that cannot be mapped into Swift.
      for segment in entry.getName().split(separator: "$") {
        if let firstChar = segment.first, firstChar.isNumber {
          continue
        }
      }

      // TODO: For now, skip all nested classes.
      if entry.getName().contains("$") {
        continue
      }

      let javaCanonicalName = String(entry.getName().replacing("/", with: ".")
        .dropLast(".class".count))
      configuration.classes[javaCanonicalName] =
        javaCanonicalName.defaultSwiftNameForJavaClass
    }

    // Encode the configuration.
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    var contents = String(data: try encoder.encode(configuration), encoding: .utf8)!
    contents.append("\n")

    // Write the file.
    try writeContents(
      contents,
      to: "Java2Swift.config",
      description: "Java2Swift configuration file"
    )
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

extension String {
  /// For a String that's of the form java.util.Vector, return the "Vector"
  /// part.
  fileprivate var defaultSwiftNameForJavaClass: String {
    if let dotLoc = lastIndex(of: ".") {
      let afterDot = index(after: dotLoc)
      return String(self[afterDot...])
    }

    return self
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
