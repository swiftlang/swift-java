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
import ArgumentParser
import SwiftJavaLib
import JavaKit
import JavaKitJar
import SwiftJavaLib
import JavaKitConfigurationShared

extension SwiftJava {

  struct WrapJavaCommand: SwiftJavaBaseAsyncParsableCommand, HasCommonOptions, HasCommonJVMOptions {
    static let configuration = CommandConfiguration(
      commandName: "wrap-java",
      abstract: "Wrap Java classes with corresponding Swift bindings.")

    @OptionGroup var commonOptions: SwiftJava.CommonOptions
    @OptionGroup var commonJVMOptions: SwiftJava.CommonJVMOptions

    @Option(help: "The name of the Swift module into which the resulting Swift types will be generated.")
    var swiftModule: String

    var effectiveSwiftModule: String {
      swiftModule
    }

    @Option(
      help: """
            A swift-java configuration file for a given Swift module name on which this module depends,
            e.g., JavaKitJar=Sources/JavaKitJar/Java2Swift.config. There should be one of these options
            for each Swift module that this module depends on (transitively) that contains wrapped Java sources.
            """
    )
    var dependsOn: [String] = []

    @Option(help: "The Java package the generated Java code should be emitted into.")
    var javaPackage: String? = nil

    @Option(help: "The names of Java classes whose declared native methods will be implemented in Swift.")
    var swiftNativeImplementation: [String] = []

    @Argument(help: "Path to .jar file whose Java classes should be wrapped using Swift bindings")
    var input: String
  }
}

extension SwiftJava.WrapJavaCommand {

  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    if let javaPackage {
      config.javaPackage = javaPackage
    }

    // Load all of the dependent configurations and associate them with Swift
    // modules.
    let dependentConfigs = try loadDependentConfigs()

    // Configure our own classpath based on config
    var classpathEntries =
      self.configureCommandJVMClasspath(effectiveSwiftModuleURL: self.effectiveSwiftModuleURL, config: config)

    // Include classpath entries which libs we depend on require...
    for (fromModule, config) in dependentConfigs {
      // TODO: may need to resolve the dependent configs rather than just get their configs
      // TODO: We should cache the resolved classpaths as well so we don't do it many times
      config.classpath.map { entry in
        print("[trace][swift-java] Add dependent config (\(fromModule)) classpath element: \(entry)")
        classpathEntries.append(entry)
      }
    }

    let completeClasspath = classpathEntries.joined(separator: ":")
    let jvm = try self.makeJVM(classpathEntries: classpathEntries)

    try self.generateWrappers(
      config: config,
      classpath: completeClasspath,
      dependentConfigs: dependentConfigs,
      environment: jvm.environment()
    )
  }
}

extension SwiftJava.WrapJavaCommand {

  /// Load all dependent configs configured with `--depends-on` and return a list of
  /// `(SwiftModuleName, Configuration)` tuples.
  func loadDependentConfigs() throws -> [(String, Configuration)] {
    try dependsOn.map { dependentConfig in
      guard let equalLoc = dependentConfig.firstIndex(of: "=") else {
        throw JavaToSwiftError.badConfigOption(dependentConfig)
      }

      let afterEqual = dependentConfig.index(after: equalLoc)
      let swiftModuleName = String(dependentConfig[..<equalLoc])
      let configFileName = String(dependentConfig[afterEqual...])

      let config = try readConfiguration(configPath: URL(fileURLWithPath: configFileName)) ?? Configuration()

      return (swiftModuleName, config)
    }
  }
}

extension SwiftJava.WrapJavaCommand {
  mutating func generateWrappers(
    config: Configuration,
    classpath: String,
    dependentConfigs: [(String, Configuration)],
    environment: JNIEnvironment
  ) throws {
    let translator = JavaTranslator(
      swiftModuleName: effectiveSwiftModule,
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
    translator.addConfiguration(config, forSwiftModule: effectiveSwiftModule)

    // Load all of the explicitly-requested classes.
    let classLoader = try JavaClass<ClassLoader>(environment: environment)
      .getSystemClassLoader()!
    var javaClasses: [JavaClass<JavaObject>] = []
    for (javaClassName, _) in config.classes ?? [:] {
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
        outputDirectory: self.actualOutputDirectory,
        to: swiftFileName,
        description: "Java class '\(javaClass.getName())' translation"
      )
    }
  }
}
