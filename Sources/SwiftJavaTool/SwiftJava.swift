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
struct SwiftJava: SwiftJavaBaseAsyncParsableCommand, HasCommonJVMOptions { // FIXME: this is just a normal async command, no parsing happening here
  static var _commandName: String { "swift-java" }

  static let configuration = CommandConfiguration(
    abstract: "Generate sources and configuration for Swift and Java interoperability.",
    subcommands: [
      ConfigureCommand.self,
      ResolveCommand.self,
    ])

  // FIXME: this must be removed when we move things out from the SwiftJava main file!
  @Option(
    name: .long,
    help: "The name of the Swift module into which the resulting Swift types will be generated.")
  var swiftModuleDeprecated: String?

  var effectiveSwiftModule: String {
    if let module = swiftModuleDeprecated {
      module
    } else if let module = self.outputSwift?.split(separator: "/").last {
      String(module)
    } else {
      "UnknownSwiftModule"
    }
  }
//
//  @Option(
//    help:
//      "A Java2Swift configuration file for a given Swift module name on which this module depends, e.g., JavaKitJar=Sources/JavaKitJar/Java2Swift.config. There should be one of these options for each Swift module that this module depends on (transitively) that contains wrapped Java sources."
//  )
//  var dependsOn: [String] = []
//
//  @Option(
//    help: "The names of Java classes whose declared native methods will be implemented in Swift."
//  )
//  var swiftNativeImplementation: [String] = []

  @Option(help: "The directory where generated Swift files should be written. Generally used with jextract mode.")
  var outputSwift: String? = nil

  @Option(help: "The directory where generated Java files should be written. Generally used with jextract mode.")
  var outputJava: String? = nil

//  @Option(help: "The Java package the generated Java code should be emitted into.")
//  var javaPackage: String? = nil

  @Option(help: "The mode of generation to use for the output files. Used with jextract mode.")
  var mode: GenerationMode = .ffm

  @Option(name: .shortAndLong, help: "Directory where to write cached values (e.g. swift-java.classpath files)")
  var cacheDirectory: String? = nil

  @OptionGroup var commonOptions: SwiftJava.CommonOptions
  @OptionGroup var commonJVMOptions: SwiftJava.CommonJVMOptions

  var effectiveCacheDirectory: String? {
    if let cacheDirectory {
      return cacheDirectory
    } else {
      return nil
    }
  }

//  @Argument(
//    help: "The input file, which is either a Java2Swift configuration file or (if '-jar' was specified) a Jar file."
//  )
  var input: String? // FIXME: top level command cannot have input argument like this

  // FIXME: this is subcommands
  /// Describes what kind of generation action is being performed by swift-java.
  enum ToolMode {
//    /// Generate Swift wrappers for Java classes based on the given
//    /// configuration.
//    case classWrappers

    /// Extract Java bindings from provided Swift sources.
    case jextract // TODO: carry jextract specific config here?
  }

  mutating func runSwiftJavaCommand(config: inout Configuration) async throws {
    guard CommandLine.arguments.count >= 2 else {
      // there's no "default" command, print USAGE when no arguments/parameters are passed.
      print("error: Must specify mode subcommand (e.g. configure, resolve, jextract, ...).\n\n\(Self.helpMessage())")
      return
    }

//    if let javaPackage {
//      config.javaPackage = javaPackage
//    }

    // Determine the mode in which we'll execute.
    let toolMode: ToolMode = .jextract

    // TODO: some options are exclusive to each other so we should detect that
    if let inputSwift = commonOptions.inputSwift {
      guard let inputSwift = commonOptions.inputSwift else {
        print("[swift-java] --input-swift enabled 'jextract' mode, however no --output-swift directory was provided!\n\(Self.helpMessage())")
        return
      }
      guard let outputSwift else {
        print("[swift-java] --output-swift enabled 'jextract' mode, however no --output-swift directory was provided!\n\(Self.helpMessage())")
        return
      }
      guard let outputJava else {
        print("[swift-java] --output-java enabled 'jextract' mode, however no --output-java directory was provided!\n\(Self.helpMessage())")
        return
      }
      config.swiftModule = self.effectiveSwiftModule
      config.inputSwiftDirectory = inputSwift
      config.outputSwiftDirectory = outputSwift
      config.outputJavaDirectory = outputJava

//      toolMode = .jextract
//    } else if fetch {
//      guard let input else {
//        fatalError("Mode 'fetch' requires <input> path\n\(Self.helpMessage())")
//      }
//      config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
//      guard let dependencies = config.dependencies else {
//        print("[swift-java] Running in 'fetch dependencies' mode but dependencies list was empty!")
//        print("[swift-java] Nothing to do: done.")
//        return
//      }
//      toolMode = .fetchDependencies
    }
//    else {
//      guard let input else {
//        fatalError("Mode -jar requires <input> path\n\(Self.helpMessage())")
//      }
//      config = try JavaTranslator.readConfiguration(from: URL(fileURLWithPath: input))
//      toolMode = .classWrappers
//    }

    print("[debug][swift-java] Running swift-java in mode: " + "\(toolMode.prettyName)".bold)

    let swiftModule: String =
      self.effectiveSwiftModule
//       ??
//      self.effectiveSwiftModule.split(separator: "/").dropLast().last.map(String.init) ?? "__UnknownModule"

//    // Load all of the dependent configurations and associate them with Swift
//    // modules.
//    let dependentConfigs = try dependsOn.map { dependentConfig in
//      guard let equalLoc = dependentConfig.firstIndex(of: "=") else {
//        throw JavaToSwiftError.badConfigOption(dependentConfig)
//      }
//
//      let afterEqual = dependentConfig.index(after: equalLoc)
//      let swiftModuleName = String(dependentConfig[..<equalLoc])
//      let configFileName = String(dependentConfig[afterEqual...])
//
//      let config = try readConfiguration(from: URL(fileURLWithPath: configFileName))
//
//      return (swiftModuleName, config)
//    }

    // Form a class path from all of our input sources:
    //   * Command-line option --classpath
    let classpathOptionEntries: [String] = self.classpathEntries
    let classpathFromEnv = self.classpathEnvEntries
    let classpathFromConfig: [String] = config.classpathEntries
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

//    switch toolMode {
//    case .fetchDependencies:
//      // if we have already fetched dependencies for the dependency loader,
//      // let's use them so we can in-process resolve rather than forking a new
//      // gradle process.
//      print("[debug][swift-java] Add classpath from .classpath files")
////        if let dependencyResolverClasspath = fetchDependenciesCachedClasspath() {
////          print("[debug][swift-java] Found cached dependency resolver classpath: \(dependencyResolverClasspath)")
////          classpathEntries += dependencyResolverClasspath
////        }
//    case .classWrappers, .jextract:
//      break;
//    }

    // Bring up the Java VM when necessary
//    // TODO: print only in verbose mode
//    let classpath = classpathEntries.joined(separator: ":")

//    let jvm: JavaVirtualMachine! = nil
//    switch toolMode {
//      case .classWrappers:
//        print("[debug][swift-java] Initialize JVM with classpath: \(classpath)")
//        jvm = try JavaVirtualMachine.shared(classpath: classpathEntries)
//      default:
//        jvm = nil
//    }

//    //   * Classpaths from all dependent configuration files
//    for (_, config) in dependentConfigs {
//      // TODO: may need to resolve the dependent configs rather than just get their configs
//      // TODO: We should cache the resolved classpaths as well so we don't do it many times
//      config.classpath.map { entry in
//        print("[swift-java] Add dependent config classpath element: \(entry)")
//        classpathEntries.append(entry)
//      }
//    }

    // Run the task.
//    switch toolMode {
////    case .classWrappers:
////      try generateWrappers(
////        config: config,
////        classpath: classpath,
////        dependentConfigs: dependentConfigs,
////        environment: jvm.environment()
////      )
//
//      case .jextract:
        try jextractSwift(config: config)
//    }
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

extension SwiftJava.ToolMode {
  var prettyName: String {
    switch self {
//      case .classWrappers: "Wrap Java classes"
      case .jextract: "JExtract Swift for Java"
    }
  }
}

extension GenerationMode: ExpressibleByArgument {}
