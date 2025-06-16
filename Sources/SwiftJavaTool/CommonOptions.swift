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
import SwiftSyntax
import JavaKitConfigurationShared
import JavaKitShared

// - MARK: Common Options

protocol HasCommonOptions {
  var commonOptions: SwiftJava.CommonOptions { get set }
}
extension HasCommonOptions {
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
    var logLevel: Logger.Level = .info
  }

  struct CommonJVMOptions: ParsableArguments {
    @Option(
      name: [.customLong("cp"), .customLong("classpath")],
      help: "Class search path of directories and zip/jar files from which Java classes can be loaded."
    )
    var classpath: [String] = []

    @Option(name: .shortAndLong, help: "While scanning a classpath, inspect only types included in this package")
    var filterJavaPackage: String? = nil
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
  func configureCommandJVMClasspath(effectiveSwiftModuleURL: Foundation.URL, config: Configuration) -> [String] {
    // Form a class path from all of our input sources:
    //   * Command-line option --classpath
    let classpathOptionEntries: [String] = self.classpathEntries
    let classpathFromEnv = ProcessInfo.processInfo.environment["CLASSPATH"]?.split(separator: ":").map(String.init) ?? []
    let classpathFromConfig: [String] = config.classpath?.split(separator: ":").map(String.init) ?? []
    print("[debug][swift-java] Base classpath from config: \(classpathFromConfig)")

    var classpathEntries: [String] = classpathFromConfig

    let classPathFilesSearchDirectory = effectiveSwiftModuleURL.absoluteString
    print("[debug][swift-java] Search *.swift-java.classpath in: \(classPathFilesSearchDirectory)")
    let swiftJavaCachedModuleClasspath = findSwiftJavaClasspaths(in: classPathFilesSearchDirectory)

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

    let extraClasspath = self.commonJVMOptions.classpath
    let extraClasspathEntries = extraClasspath.split(separator: ":").map(String.init)
    print("[debug][swift-java] Extra classpath: \(extraClasspathEntries)")
    classpathEntries += extraClasspathEntries

    // Bring up the Java VM when necessary

    // if logLevel >= .debug {
      let classpathString = classpathEntries.joined(separator: ":")
      print("[debug][swift-java] Initialize JVM with classpath: \(classpathString)")
    // }

    return classpathEntries
  }

  func makeJVM(classpathEntries: [String]) throws -> JavaVirtualMachine {
    try JavaVirtualMachine.shared(classpath: classpathEntries)
  }
}