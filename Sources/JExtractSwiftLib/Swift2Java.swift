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
import OrderedCollections

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
    let log = translator.log

    if config.javaPackage == nil || config.javaPackage!.isEmpty {
      translator.log.warning("Configured java package is '', consider specifying concrete package for generated sources.")
    }

    guard let inputSwift = config.inputSwiftDirectory else {
      fatalError("Missing '--swift-input' directory!")
    }

    log.info("Input swift = \(inputSwift)")
    let inputPaths = inputSwift.split(separator: ",").map { URL(string: String($0))! }
    log.info("Input paths = \(inputPaths)")

    let allFiles = collectAllFiles(suffix: ".swift", in: inputPaths, log: translator.log)

    // Register files to the translator.
    let fileManager = FileManager.default
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

    switch config.effectiveMode {
    case .ffm:
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
    guard file.lastPathComponent.hasSuffix(".swift") || 
          file.lastPathComponent.hasSuffix(".swiftinterface") else {
      return false
    }
    if file.lastPathComponent.hasSuffix("+SwiftJava.swift") {
      return false
    }

    return true
  }

}

extension URL {
  var isDirectory: Bool {
    var isDir: ObjCBool = false
    _ = FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
    return isDir.boolValue
  }
}

/// Collect all files with given 'suffix', will explore directories recursively.
public func collectAllFiles(suffix: String, in inputPaths: [URL], log: Logger) -> OrderedSet<URL> {
  guard !inputPaths.isEmpty else {
    return []
  }

  let fileManager = FileManager.default
  var allFiles: OrderedSet<URL> = []
  allFiles.reserveCapacity(32) // rough guesstimate
  
  let resourceKeys: [URLResourceKey] = [
    .isRegularFileKey,
    .isDirectoryKey,
    .nameKey
  ]
  
  for path in inputPaths {
    do {
      try collectFilesFromPath(
        path,
        suffix: suffix,
        fileManager: fileManager,
        resourceKeys: resourceKeys,
        into: &allFiles,
        log: log
      )
    } catch {
      log.trace("Failed to collect paths in: \(path), skipping.")
    }
  }
  
  return allFiles 
}

private func collectFilesFromPath(
  _ path: URL,
  suffix: String,
  fileManager: FileManager,
  resourceKeys: [URLResourceKey],
  into allFiles: inout OrderedSet<URL>,
  log: Logger
) throws {
  guard fileManager.fileExists(atPath: path.path) else {
    return
  }
  
  if path.isDirectory {
    let enumerator = fileManager.enumerator(
      at: path,
      includingPropertiesForKeys: resourceKeys,
      options: [.skipsHiddenFiles],
      errorHandler: { url, error in
        return true
      })
    guard let enumerator else {
      return
    }
    
    for case let fileURL as URL in enumerator {
      try? collectFilesFromPath(fileURL, suffix: suffix, fileManager: fileManager, resourceKeys: resourceKeys, into: &allFiles, log: log)
    }
  } 
  
  guard path.isFileURL else {
    return
  }
  guard path.lastPathComponent.hasSuffix(suffix) else {
    return
  }
  allFiles.append(path)
}
