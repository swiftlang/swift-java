//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
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
import SwiftJavaToolLib
import SwiftJava
import JavaUtilJar
import SwiftJavaToolLib
import SwiftJavaConfigurationShared

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
            e.g., JavaKitJar=Sources/JavaKitJar/swift-java.config. There should be one of these options
            for each Swift module that this module depends on (transitively) that contains wrapped Java sources.
            """
    )
    var dependsOn: [String] = []

    @Option(help: "The names of Java classes whose declared native methods will be implemented in Swift.")
    var swiftNativeImplementation: [String] = []

    @Option(help: "Cache directory for intermediate results and other outputs between runs")
    var cacheDirectory: String?

    @Option(help: "Match java package directory structure with generated Swift files")
    var swiftMatchPackageDirectoryStructure: Bool = false

    @Argument(help: "Path to .jar file whose Java classes should be wrapped using Swift bindings")
    var input: String
  }
}

extension SwiftJava.WrapJavaCommand {

  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    // Get base classpath configuration for this target and configuration
    var classpathSearchDirs = [self.effectiveSwiftModuleURL]
    if let cacheDir = self.cacheDirectory {
      print("[trace][swift-java] Cache directory: \(cacheDir)")
      classpathSearchDirs += [URL(fileURLWithPath: cacheDir)]
    } else {
      print("[trace][swift-java] Cache directory: none")
    }
    print("[trace][swift-java] INPUT: \(input)")

    var classpathEntries = self.configureCommandJVMClasspath(
        searchDirs: classpathSearchDirs, config: config)

    // Load all of the dependent configurations and associate them with Swift modules.
    let dependentConfigs = try loadDependentConfigs(dependsOn: self.dependsOn).map { moduleName, config in
      guard let moduleName else {
        throw JavaToSwiftError.badConfigOption
      }
      return (moduleName, config)
    }
    print("[debug][swift-java] Dependent configs: \(dependentConfigs.count)")

    // Include classpath entries which libs we depend on require...
    for (fromModule, config) in dependentConfigs {
      print("[trace][swift-java] Add dependent config (\(fromModule)) classpath elements: \(config.classpathEntries.count)")
      // TODO: may need to resolve the dependent configs rather than just get their configs
      // TODO: We should cache the resolved classpaths as well so we don't do it many times
      for entry in config.classpathEntries {
        print("[trace][swift-java] Add dependent config (\(fromModule)) classpath element: \(entry)")
        classpathEntries.append(entry)
      }
    }

    let jvm = try self.makeJVM(classpathEntries: classpathEntries)

    try self.generateWrappers(
      config: config,
      // classpathEntries: classpathEntries,
      dependentConfigs: dependentConfigs,
      environment: jvm.environment()
    )
  }
}

extension SwiftJava.WrapJavaCommand {
  mutating func generateWrappers(
    config: Configuration,
    // classpathEntries: [String],
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

      var generatedFileOutputDir = self.actualOutputDirectory
      if self.swiftMatchPackageDirectoryStructure {
        generatedFileOutputDir?.append(path: javaClass.getPackageName().replacing(".", with: "/"))
      }

      let swiftFileName = try! translator.getSwiftTypeName(javaClass, preferValueTypes: false)
        .swiftName.replacing(".", with: "+") + ".swift"
      try writeContents(
        swiftFileText,
        outputDirectory: generatedFileOutputDir,
        to: swiftFileName,
        description: "Java class '\(javaClass.getName())' translation"
      )
    }
  }
}
