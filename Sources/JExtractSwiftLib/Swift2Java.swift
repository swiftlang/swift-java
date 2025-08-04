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
import SwiftJavaShared
import SwiftJavaConfigurationShared

public struct SwiftToJava {
  let config: Configuration
  let dependentConfigs: [Configuration]

  public init(config: Configuration, dependentConfigs: [Configuration]) {
    self.config = config
    self.dependentConfigs = dependentConfigs
  }

  public func run() throws {
    guard let swiftModule = config.swiftModule else {
      fatalError("Missing '--swift-module' name.")
    }

    let translator = Swift2JavaTranslator(config: config)
    translator.log.logLevel = config.logLevel ?? .info

    if config.javaPackage == nil || config.javaPackage!.isEmpty {
      translator.log.warning("Configured java package is '', consider specifying concrete package for generated sources.")
    }

    guard let inputSwift = config.inputSwiftDirectory else {
      fatalError("Missing '--swift-input' directory!")
    }

    translator.log.info("Input swift = \(inputSwift)")
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

    let wrappedJavaClassesLookupTable: JavaClassLookupTable = dependentConfigs.compactMap(\.classes).reduce(into: [:]) {
      for (canonicalName, javaClass) in $1 {
        $0[javaClass] = canonicalName
      }
    }

    translator.dependenciesClasses = Array(wrappedJavaClassesLookupTable.keys)

    try translator.analyze()

    switch config.mode {
    case .some(.ffm), .none:
      let generator = FFMSwift2JavaGenerator(
        config: self.config,
        translator: translator,
        javaPackage: config.javaPackage ?? "",
        swiftOutputDirectory: outputSwiftDirectory,
        javaOutputDirectory: outputJavaDirectory
      )

      try generator.generate()

    case .jni:
      let generator = JNISwift2JavaGenerator(
        config: self.config,
        translator: translator,
        javaPackage: config.javaPackage ?? "",
        swiftOutputDirectory: outputSwiftDirectory,
        javaOutputDirectory: outputJavaDirectory,
        javaClassLookupTable: wrappedJavaClassesLookupTable
      )

      try generator.generate()
    }

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
