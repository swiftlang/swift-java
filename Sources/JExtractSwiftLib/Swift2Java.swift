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
import SwiftSyntax
import SwiftSyntaxBuilder
import JavaKitShared
import JavaKitConfigurationShared // TODO: this should become SwiftJavaConfigurationShared

public struct SwiftToJava {
  let config: Configuration

  public init(config: Configuration) {
    self.config = config
  }

  public func run() throws {
    guard let swiftModule = config.swiftModule else {
      fatalError("Missing '--swift-module' name.")
    }

    let translator = Swift2JavaTranslator(
      javaPackage: config.javaPackage ?? "", // no package is ok, we'd generate all into top level
      swiftModuleName: swiftModule
    )
    translator.log.logLevel = config.logLevel ?? .info

    if config.javaPackage == nil || config.javaPackage!.isEmpty {
      translator.log.warning("Configured java package is '', consider specifying concrete package for generated sources.")
    }

    print("===== CONFIG ==== \(config)")

    guard let inputSwift = config.inputSwiftDirectory else {
      fatalError("Missing '--swift-input' directory!")
    }

    let inputPaths = inputSwift.split(separator: ",").map { URL(string: String($0))! }
    translator.log.info("Input paths = \(inputPaths)")

    var allFiles: [URL] = []
    let fileManager = FileManager.default
    let log = translator.log

    for path in inputPaths {
      log.info("Input path: \(path)")
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

    // Register files to the translator.
    for file in allFiles {
      guard canExtract(from: file) else {
        continue
      }
      guard let data = fileManager.contents(atPath: file.path) else {
        continue
      }
      guard let text = String(data:data, encoding: .utf8) else {
        continue
      }
      translator.add(filePath: file.path, text: text)
    }

    guard let outputSwiftDirectory = config.outputSwiftDirectory else {
      fatalError("Missing --output-swift directory!")
    }
    guard let outputJavaDirectory = config.outputJavaDirectory else {
      fatalError("Missing --output-java directory!")
    }

    try translator.analyze()

    switch mode {
    case .ffm:
      let generator = FFMSwift2JavaGenerator(
        translator: translator,
        javaPackage: self.packageName,
        swiftOutputDirectory: outputDirectorySwift,
        javaOutputDirectory: outputDirectoryJava
      )

      try generator.generate()
    }


    print("[swift-java] Generated Java sources (\(packageName)) in: \(outputDirectoryJava)/")

    try translator.writeSwiftThunkSources(outputDirectory: outputSwiftDirectory)
    print("[swift-java] Generated Swift sources (module: '\(config.swiftModule ?? "")') in: \(outputSwiftDirectory)/")

    try translator.writeExportedJavaSources(outputDirectory: outputJavaDirectory)
    print("[swift-java] Generated Java sources (package: '\(config.javaPackage ?? "")') in: \(outputJavaDirectory)/")

    print("[swift-java] Imported Swift module '\(swiftModule)': " + "done.".green)
  }
  
  func canExtract(from file: URL) -> Bool {
    file.lastPathComponent.hasSuffix(".swift") ||
    file.lastPathComponent.hasSuffix(".swiftinterface")
  }

}

func isDirectory(url: URL) -> Bool {
  var isDirectory: ObjCBool = false
  _ = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
  return isDirectory.boolValue
}
