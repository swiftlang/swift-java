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
import SwiftSyntax
import SwiftSyntaxBuilder

/// Command-line utility, similar to `jextract` to export Swift types to Java.
public struct SwiftToJava: AsyncParsableCommand {
  public init() {}

  public static var _commandName: String {
    "jextract-swift"
  }

  @Option(help: "The package the generated Java code should be emitted into.")
  var packageName: String

  @Option(name: .shortAndLong, help: "The directory in which to output the generated Swift files and manifest.")
  var outputDirectory: String = ".build/jextract-swift/generated"

  @Option(name: .long, help: "Name of the Swift module to import (and the swift interface files belong to)")
  var swiftModule: String

  // TODO: Once we ship this, make this `.warning` by default
  @Option(name: .shortAndLong, help: "Configure the level of lots that should be printed")
  var logLevel: Logger.Level = .trace

  @Argument(help: "The Swift interface files to export to Java.")
  var swiftInterfaceFiles: [String]

  public func run() async throws {
    let interfaceFiles = self.swiftInterfaceFiles.dropFirst()
    print("Interface files: \(interfaceFiles)")

    let translator = Swift2JavaTranslator(
      javaPackage: packageName,
      swiftModuleName: swiftModule
    )
    translator.log.logLevel = logLevel

    var fileNo = 1
    for interfaceFile in interfaceFiles {
      print("[\(fileNo)/\(interfaceFiles.count)] Importing module '\(swiftModule)', interface file: \(interfaceFile)")
      defer { fileNo += 1 }

      try await translator.analyze(swiftInterfacePath: interfaceFile)
      try translator.writeImportedTypesTo(outputDirectory: outputDirectory)

      print("[\(fileNo)/\(interfaceFiles.count)] Imported interface file: \(interfaceFile) " + "done.".green)
    }

    try translator.writeModuleTo(outputDirectory: outputDirectory)
    print("")
    print("Generated Java sources in package '\(packageName)' in: \(outputDirectory)/")
    print("Swift module '\(swiftModule)' import: " + "done.".green)
  }

}

extension Logger.Level: ExpressibleByArgument {
  public var defaultValueDescription: String {
    "log level"
  }
  public private(set) static var allValueStrings: [String] =
    ["trace", "debug", "info", "notice", "warning", "error", "critical"]

  public private(set) static var defaultCompletionKind: CompletionKind = .default
}
