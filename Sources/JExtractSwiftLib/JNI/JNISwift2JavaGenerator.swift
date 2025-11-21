//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaTypes
import SwiftJavaConfigurationShared

/// A table that where keys are Swift class names and the values are
/// the fully qualified canoical names.
package typealias JavaClassLookupTable = [String: String]

package class JNISwift2JavaGenerator: Swift2JavaGenerator {

  let logger: Logger
  let config: Configuration
  let analysis: AnalysisResult
  let swiftModuleName: String
  let javaPackage: String
  let swiftOutputDirectory: String
  let javaOutputDirectory: String
  let lookupContext: SwiftTypeLookupContext

  let javaClassLookupTable: JavaClassLookupTable

  var javaPackagePath: String {
    javaPackage.replacingOccurrences(of: ".", with: "/")
  }

  var thunkNameRegistry = ThunkNameRegistry()

  /// Cached Java translation result. 'nil' indicates failed translation.
  var translatedDecls: [ImportedFunc: TranslatedFunctionDecl] = [:]
  var translatedEnumCases: [ImportedEnumCase: TranslatedEnumCase] = [:]

  /// Because we need to write empty files for SwiftPM, keep track which files we didn't write yet,
  /// and write an empty file for those.
  ///
  /// Since Swift files in SwiftPM builds needs to be unique, we use this fact to flatten paths into plain names here.
  /// For uniqueness checking "did we write this file already", just checking the name should be sufficient.
  var expectedOutputSwiftFileNames: Set<String>

  package init(
    config: Configuration,
    translator: Swift2JavaTranslator,
    javaPackage: String,
    swiftOutputDirectory: String,
    javaOutputDirectory: String,
    javaClassLookupTable: JavaClassLookupTable
  ) {
    self.config = config
    self.logger = Logger(label: "jni-generator", logLevel: translator.log.logLevel)
    self.analysis = translator.result
    self.swiftModuleName = translator.swiftModuleName
    self.javaPackage = javaPackage
    self.swiftOutputDirectory = swiftOutputDirectory
    self.javaOutputDirectory = javaOutputDirectory
    self.javaClassLookupTable = javaClassLookupTable
    self.lookupContext = translator.lookupContext

    // If we are forced to write empty files, construct the expected outputs.
    // It is sufficient to use file names only, since SwiftPM requires names to be unique within a module anyway.
    if translator.config.writeEmptyFiles ?? false {
      self.expectedOutputSwiftFileNames = Set(translator.inputs.compactMap { (input) -> String? in
        // guard let filePathPart = input.path.split(separator: "/\(translator.swiftModuleName)/").last else {
        //   return nil
        // }
        // return String(filePathPart.replacing(".swift", with: "+SwiftJava.swift"))
        guard let fileName = input.path.split(separator: PATH_SEPARATOR).last else {
          return nil
        }
        guard fileName.hasSuffix(".swift") else {
          return nil
        }
        return String(fileName.replacing(".swift", with: "+SwiftJava.swift"))
      })
      self.expectedOutputSwiftFileNames.insert("\(translator.swiftModuleName)Module+SwiftJava.swift")
      self.expectedOutputSwiftFileNames.insert("Foundation+SwiftJava.swift")
    } else {
      self.expectedOutputSwiftFileNames = []
    }
  }

  func generate() throws {
    try writeSwiftThunkSources()
    try writeExportedJavaSources()

    let pendingFileCount = self.expectedOutputSwiftFileNames.count
    if pendingFileCount > 0 {
      print("[swift-java] Write empty [\(pendingFileCount)] 'expected' files in: \(swiftOutputDirectory)/")
      try writeSwiftExpectedEmptySources()
    }
  }
}
