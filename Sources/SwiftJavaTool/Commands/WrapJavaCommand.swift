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
import Logging
import SwiftJavaToolLib
import SwiftJava
import JavaUtilJar
import SwiftJavaConfigurationShared

extension SwiftJava {

  struct WrapJavaCommand: SwiftJavaBaseAsyncParsableCommand, HasCommonOptions, HasCommonJVMOptions {

    static let log: Logging.Logger = .init(label: "swift-java:\(configuration.commandName!)")

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

    @Option(help: "If specified, a single Swift file will be generated containing all the generated code")
    var singleSwiftFileOutput: String?
  }
}

extension SwiftJava.WrapJavaCommand {

  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    print("self.commonOptions.filterInclude = \(self.commonOptions.filterInclude)")
    configure(&config.filterInclude, append: self.commonOptions.filterInclude)
    configure(&config.filterExclude, append: self.commonOptions.filterExclude)
    configure(&config.singleSwiftFileOutput, overrideWith: self.singleSwiftFileOutput)

    // Get base classpath configuration for this target and configuration
    var classpathSearchDirs = [self.effectiveSwiftModuleURL]
    if let cacheDir = self.cacheDirectory {
      print("[trace][swift-java] Cache directory: \(cacheDir)")
      classpathSearchDirs += [URL(fileURLWithPath: cacheDir)]
    } else {
      print("[trace][swift-java] Cache directory: none")
    }

    var classpathEntries = self.configureCommandJVMClasspath(
        searchDirs: classpathSearchDirs, config: config, log: Self.log)

    // Load all of the dependent configurations and associate them with Swift modules.
    let dependentConfigs = try loadDependentConfigs(dependsOn: self.dependsOn).map { moduleName, config in
      guard let moduleName else {
        throw JavaToSwiftError.badConfigOption(self.dependsOn.joined(separator: " "))
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
    dependentConfigs: [(String, Configuration)],
    environment: JNIEnvironment
  ) throws {
    let translator = JavaTranslator(
      config: config,
      swiftModuleName: effectiveSwiftModule,
      environment: environment,
      translateAsClass: true
    )

    log.info("Active include filters: \(config.filterInclude ?? [])")
    log.info("Active exclude filters: \(config.filterExclude ?? [])")

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
    let classLoader = try! JavaClass<ClassLoader>(environment: environment)
      .getSystemClassLoader()!
    var javaClasses: [JavaClass<JavaObject>] = []
    for (javaClassName, _) in config.classes ?? [:] {
      func remove() {
        translator.translatedClasses.removeValue(forKey: javaClassName)
      }

      guard shouldImportJavaClass(javaClassName, config: config) else {
        remove()
        continue
      }

      guard let javaClass = try classLoader.loadClass(javaClassName) else {
        log.warning("Could not load Java class '\(javaClassName)', skipping.")
        remove()
        continue
      }

      guard self.shouldExtract(javaClass: javaClass, config: config) else {
        log.info("Skip Java type: \(javaClassName) (does not match minimum access level)")
        remove()
        continue
      }

      guard !javaClass.isEnum() else {
        log.info("Skip Java type: \(javaClassName) (enums do not currently work)")
        remove()
        continue
      }

      log.info("Wrapping java type: \(javaClassName)")

      // Add this class to the list of classes we'll translate.
      javaClasses.append(javaClass)
    }

    log.info("OK now we go to nested classes")

    // Find all of the nested classes for each class, adding them to the list
    // of classes to be translated if they were already specified.
    var allClassesToVisit = javaClasses
    var currentClassIndex: Int = 0
    outerClassLoop: while currentClassIndex < allClassesToVisit.count {
      defer {
        currentClassIndex += 1
      }

      // The current top-level class we're in.
      let currentClass = allClassesToVisit[currentClassIndex]
      let currentClassName = currentClass.getName()
      guard let currentSwiftName = translator.translatedClasses[currentClass.getName()]?.swiftType else {
        continue
      }

      // Find all of the nested classes that weren't explicitly translated already.
      let nestedAndSuperclassNestedClasses = currentClass.getClasses() // watch out, this includes nested types from superclasses
      let nestedClasses: [JavaClass<JavaObject>] = nestedAndSuperclassNestedClasses.compactMap { nestedClass in
        guard let nestedClass else { 
          return nil 
        }

        // If this is a local class, we're done.
        let javaClassName = nestedClass.getName()
        if javaClassName.isLocalJavaClass {
          return nil
        }

        // We only want to visit and import types which are explicitly inside this decl,
        // and NOT any of the types contained in the super classes. That would violate our "current class"
        // nesting, because those are *actually* nested in the other class, not "the current one" (i.e. in a super class).
        guard javaClassName.hasPrefix(currentClassName) else {
          log.trace("Skip super-class nested class '\(javaClassName)', is not member of \(currentClassName). Will be visited independently.")
          return nil
        }

        guard shouldImportJavaClass(javaClassName, config: config) else {
          return nil
        }

        // If this class has been explicitly mentioned, we're done.
        guard translator.translatedClasses[javaClassName] == nil else {
          return nil
        }

        guard self.shouldExtract(javaClass: nestedClass, config: config) else {
          log.info("Skip Java type: \(javaClassName) (does not match minimum access level)")
          return nil
        }

        guard !nestedClass.isEnum() else {
          log.info("Skip Java type: \(javaClassName) (enums do not currently work)")
          return nil
        }

        // Record this as a translated class.
        let swiftUnqualifiedName = javaClassName.javaClassNameToCanonicalName
          .defaultSwiftNameForJavaClass

        let swiftName = "\(currentSwiftName).\(swiftUnqualifiedName)"
        let translatedSwiftName = SwiftTypeName(module: nil, name: swiftName)
        translator.translatedClasses[javaClassName] = translatedSwiftName
        log.debug("Record translated Java class '\(javaClassName)' -> \(translatedSwiftName)")
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

    if let singleSwiftFileOutput = config.singleSwiftFileOutput {
      translator.startNewFile()

      let swiftClassDecls = try javaClasses.flatMap {
        try translator.translateClass($0)
      }
      let importDecls = translator.getImportDecls()

      let swiftFileText = """
                          // Auto-generated by Java-to-Swift wrapper generator.
                          \(importDecls.map { $0.description }.joined())
                          \(swiftClassDecls.map { $0.description }.joined(separator: "\n"))

                          """

      try writeContents(
        swiftFileText,
        outputDirectory: self.actualOutputDirectory,
        to: singleSwiftFileOutput,
        description: "Java class translation"
      )
    } else {
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

        let swiftFileName = try translator.getSwiftTypeName(javaClass, preferValueTypes: false)
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

  /// Determines whether a method should be extracted for translation.
  /// Only look at public and protected methods here.
  private func shouldExtract<T>(javaClass: JavaClass<T>, config: Configuration) -> Bool {
    switch config.effectiveMinimumInputAccessLevelMode {
      case .internal:
        return javaClass.isPublic || javaClass.isProtected || javaClass.isPackage
      case .package:
        return javaClass.isPublic || javaClass.isProtected || javaClass.isPackage
      case .public:
        return javaClass.isPublic || javaClass.isProtected
    }
  }

  private func shouldImportJavaClass(_ javaClassName: String, config: Configuration) -> Bool {
    // If we have an inclusive filter, import only types from it
    if let includes = config.filterInclude, !includes.isEmpty {
      let anyIncludeFilterMatched = includes.contains { include in
        if javaClassName.starts(with: include) {
          // TODO: lower to trace level
          return true
        }

        log.info("Skip Java type: \(javaClassName) (does not match any include filter)")
        return false
      }

      guard anyIncludeFilterMatched else {
        log.info("Skip Java type: \(javaClassName) (does not match any include filter)")
        return false
      }
    }
    // If we have an exclude filter, check for it as well
    for exclude in config.filterExclude ?? [] {
      if javaClassName.starts(with: exclude) {
        log.info("Skip Java type: \(javaClassName) (does match exclude filter: \(exclude))")
        return false
      }
    }

    // The class matches import filters, if any, and was not excluded.
    return true
  }

}
