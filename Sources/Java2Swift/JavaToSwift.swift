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
      environment: environment,
      translateAsClass: true
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

    // Load all of the explicitly-requested classes.
    let classLoader = try JavaClass<ClassLoader>(environment: environment)
      .getSystemClassLoader()!
    var javaClasses: [JavaClass<JavaObject>] = []
    for (javaClassName, swiftName) in config.classes {
      guard let javaClass = try classLoader.loadClass(javaClassName) else {
        print("warning: could not find Java class '\(javaClassName)'")
        continue
      }

      // Add this class to the list of classes we'll translate.
      javaClasses.append(javaClass)
    }

    // Find all of the nested classes for each class, adding them to the list
    // of classes to be translated if they were already specified.
    var allClassesToVisit = javaClasses
    var currentClassIndex: Int = 0
    while currentClassIndex < allClassesToVisit.count {
      defer {
        currentClassIndex += 1
      }

      // The current class we're in.
      let currentClass = allClassesToVisit[currentClassIndex]
      guard let currentSwiftName = translator.translatedClasses[currentClass.getName()]?.swiftType else {
        continue
      }

      // Find all of the nested classes that weren't explicitly translated
      // already.
      let nestedClasses: [JavaClass<JavaObject>] = currentClass.getClasses().compactMap { nestedClass in
        guard let nestedClass else { return nil }

        // If this is a local class, we're done.
        let javaClassName = nestedClass.getName()
        if javaClassName.isLocalJavaClass {
          return nil
        }

        // If this class has been explicitly mentioned, we're done.
        if translator.translatedClasses[javaClassName] != nil {
          return nil
        }

        // Record this as a translated class.
        let swiftUnqualifiedName = javaClassName.javaClassNameToCanonicalName
          .defaultSwiftNameForJavaClass


        let swiftName = "\(currentSwiftName).\(swiftUnqualifiedName)"
        translator.translatedClasses[javaClassName] = (swiftName, nil)
        return nestedClass
      }

      // If there were no new nested classes, there's nothing to do.
      if nestedClasses.isEmpty {
        continue
      }

      // Record all of the nested classes that we will visit.
      translator.nestedClasses[currentClass.getName()] = nestedClasses
      allClassesToVisit.append(contentsOf: nestedClasses)
    }

    // Validate configurations before writing any files
    try translator.validateClassConfiguration()

    // Translate all of the Java classes into Swift classes.
    for javaClass in javaClasses {
      translator.startNewFile()
      let swiftClassDecls = try translator.translateClass(javaClass)
      let importDecls = translator.getImportDecls()

      let swiftFileText = """
        // Auto-generated by Java-to-Swift wrapper generator.
        \(importDecls.map { $0.description }.joined())
        \(swiftClassDecls.map { $0.description }.joined(separator: "\n"))

        """

      let swiftFileName = try! translator.getSwiftTypeName(javaClass, preferValueTypes: false)
        .swiftName.replacing(".", with: "+") + ".swift"
      try writeContents(
        swiftFileText,
        to: swiftFileName,
        description: "Java class '\(javaClass.getName())' translation"
      )
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

      // If this is a local class, it cannot be mapped into Swift.
      if entry.getName().isLocalJavaClass {
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
      to: "swift-java.config",
      description: "swift-java configuration file"
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
      return String(self[afterDot...]).javaClassNameToCanonicalName.adjustedSwiftTypeName
    }

    return javaClassNameToCanonicalName.adjustedSwiftTypeName
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

extension String {
  /// Replace all of the $'s for nested names with "." to turn a Java class
  /// name into a Java canonical class name,
  fileprivate var javaClassNameToCanonicalName: String {
    return replacing("$", with: ".")
  }

  /// Whether this is the name of an anonymous class.
  fileprivate var isLocalJavaClass: Bool {
    for segment in split(separator: "$") {
      if let firstChar = segment.first, firstChar.isNumber {
        return true
      }
    }

    return false
  }

  /// Adjust type name for "bad" type names that don't work well in Swift.
  fileprivate var adjustedSwiftTypeName: String {
    switch self {
    case "Type": return "JavaType"
    default: return self
    }
  }
}
