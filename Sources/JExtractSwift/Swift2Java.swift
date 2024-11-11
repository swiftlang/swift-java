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
public struct SwiftToJava: ParsableCommand {
  public init() {}

  public static var _commandName: String {
    "jextract-swift"
  }

  @Option(help: "The package the generated Java code should be emitted into.")
  var packageName: String

  @Option(
    name: .shortAndLong,
    help: "The directory in which to output the generated Swift files and manifest.")
  var outputDirectoryJava: String = ".build/jextract-swift/generated"

  @Option(help: "Swift output directory")
  var outputDirectorySwift: String

  @Option(
    name: .long,
    help: "Name of the Swift module to import (and the swift interface files belong to)")
  var swiftModule: String

  @Option(name: .shortAndLong, help: "Configure the level of lots that should be printed")
  var logLevel: Logger.Level = .info

  @Argument(help: "The Swift files or directories to recursively export to Java.")
  var input: [String]

  public func run() throws {
    let inputPaths = self.input.dropFirst().map { URL(string: $0)! }

    let translator = Swift2JavaTranslator(
      javaPackage: packageName,
      swiftModuleName: swiftModule
    )
    translator.log.logLevel = logLevel

    var allFiles: [URL] = []
    let fileManager = FileManager.default
    let log = translator.log
    
    for path in inputPaths {
      log.debug("Input path: \(path)")
      if isDirectory(url: path) {
        if let enumerator = fileManager.enumerator(at: path, includingPropertiesForKeys: nil) {
          for case let fileURL as URL in enumerator {
            allFiles.append(fileURL)
          }
        }
      } else if path.isFileURL {
        allFiles.append(path)
      }
    }

    for file in allFiles where canExtract(from: file) {
      translator.log.debug("Importing module '\(swiftModule)', file: \(file)")

      try translator.analyze(file: file.path)
      try translator.writeExportedJavaSources(outputDirectory: outputDirectoryJava)
      try translator.writeSwiftThunkSources(outputDirectory: outputDirectorySwift)

      log.debug("[swift-java] Imported interface file: \(file.path)")
    }

    try translator.writeExportedJavaModule(outputDirectory: outputDirectoryJava)
    print("[swift-java] Generated Java sources (\(packageName)) in: \(outputDirectoryJava)/")
    print("[swift-java] Imported Swift module '\(swiftModule)': " + "done.".green)
  }
  
  func canExtract(from file: URL) -> Bool {
    file.lastPathComponent.hasSuffix(".swift") ||
    file.lastPathComponent.hasSuffix(".swiftinterface")
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

func isDirectory(url: URL) -> Bool {
  var isDirectory: ObjCBool = false
  _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
  return isDirectory.boolValue
}
