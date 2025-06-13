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

protocol HasCommonOptions {
  var commonOptions: SwiftJava.CommonOptions { get set }
}

protocol HasCommonJVMOptions {
  var commonJVMOptions: SwiftJava.CommonJVMOptions { get set }
}

extension SwiftJava {
  struct CommonOptions: ParsableArguments {
    // TODO: clarify this vs outputSwift (history: outputSwift is jextract, and this was java2swift)
    @Option(name: .shortAndLong, help: "The directory in which to output the generated Swift files or the SwiftJava configuration file.")
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