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
import SwiftJavaToolLib
import JExtractSwiftLib
import SwiftJava
import JavaUtilJar
import JavaNet
import SwiftSyntax
import Logging
import SwiftJavaConfigurationShared
import SwiftJavaShared

// - MARK: Common Options

protocol HasCommonOptions {
  var commonOptions: SwiftJava.CommonOptions { get set }
}
extension HasCommonOptions {
  func configure<T>(_ setting: inout T?, overrideWith value: T?) {
    if let value {
      setting = value
    }
  }
  
  func configure<T>(_ setting: inout [T]?, append value: [T]?) {
    if let value {
      setting?.append(contentsOf: value)
    }
  }

  var outputDirectory: String? {
    self.commonOptions.outputDirectory
  }
}

extension SwiftJava {
  struct CommonOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "The directory in which to output generated SwiftJava configuration files.")
    var outputDirectory: String? = nil

    @Option(help: "Directory containing Swift files which should be extracted into Java bindings. Also known as 'jextract' mode. Must be paired with --output-java and --output-swift.")
    var inputSwift: String? = nil

    @Option(name: .shortAndLong, help: "Configure the level of logs that should be printed")
    var logLevel: JExtractSwiftLib.Logger.Level = .info

    @Option(name: .long, help: "While scanning a classpath, inspect ONLY types included in these packages")
    var filterInclude: [String] = []

    @Option(name: .long, help: "While scanning a classpath, skip types which match the filter prefix")
    var filterExclude: [String] = []
  }

  struct CommonJVMOptions: ParsableArguments {
    @Option(
      name: [.customLong("cp"), .customLong("classpath")],
      help: "Class search path of directories and zip/jar files from which Java classes can be loaded."
    )
    var classpath: [String] = []
  }
}

// - MARK: Common JVM Options

protocol HasCommonJVMOptions {
  var commonJVMOptions: SwiftJava.CommonJVMOptions { get set }
}
extension HasCommonJVMOptions {
  var classpathEntries: [String] {
    self.commonJVMOptions.classpath.flatMap { $0.split(separator: ":").map(String.init) }
  }
  var classpathEnvEntries: [String] {
    ProcessInfo.processInfo.environment["CLASSPATH"]?.split(separator: ":").map(String.init) ?? []
  }
}

extension HasCommonJVMOptions {

  /// Collect classpath information from various sources such as CLASSPATH, `-cp` option and
  /// swift-java.classpath files as configured.
  /// Parameters:
  ///   - searchDirs: search directories where we can find swift.java.classpath files to include in the configuration
  func configureCommandJVMClasspath(searchDirs: [Foundation.URL], config: Configuration, log: Logging.Logger) -> [String] {
    // Form a class path from all of our input sources:
    //   * Command-line option --classpath
    let classpathOptionEntries: [String] = self.classpathEntries
    let classpathFromEnv = ProcessInfo.processInfo.environment["CLASSPATH"]?.split(separator: ":").map(String.init) ?? []
    log.debug("Base classpath from CLASSPATH environment: \(classpathFromEnv)")
    let classpathFromConfig: [String] = config.classpath?.split(separator: ":").map(String.init) ?? []
    log.debug("Base classpath from config: \(classpathFromConfig)")

    var classpathEntries: [String] = classpathFromConfig

    for searchDir in searchDirs {
      let classPathFilesSearchDirectory = searchDir.path
      log.debug("Search *.swift-java.classpath in: \(classPathFilesSearchDirectory)")
      let foundSwiftJavaClasspath = findSwiftJavaClasspaths(in: classPathFilesSearchDirectory)

      log.debug("Classpath from *.swift-java.classpath files: \(foundSwiftJavaClasspath)")
      classpathEntries += foundSwiftJavaClasspath
    }

    if !classpathOptionEntries.isEmpty {
      log.debug("Classpath from options: \(classpathOptionEntries)")
      classpathEntries += classpathOptionEntries
    } else {
      // * Base classpath from CLASSPATH env variable
      log.debug("Classpath from environment: \(classpathFromEnv)")
      classpathEntries += classpathFromEnv
    }

    let extraClasspath = self.commonJVMOptions.classpath
    let extraClasspathEntries = extraClasspath.split(separator: ":").map(String.init)
    log.debug("Extra classpath: \(extraClasspathEntries)")
    classpathEntries += extraClasspathEntries

    // Bring up the Java VM when necessary

    if log.logLevel >= .debug {
      let classpathString = classpathEntries.joined(separator: ":")
      log.debug("Initialize JVM with classpath: \(classpathString)")
    }

    return classpathEntries
  }

  func makeJVM(classpathEntries: [String]) throws -> JavaVirtualMachine {
    try JavaVirtualMachine.shared(classpath: classpathEntries)
  }
}