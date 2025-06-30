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

package class JNISwift2JavaGenerator: Swift2JavaGenerator {
  let analysis: AnalysisResult
  let swiftModuleName: String
  let javaPackage: String
  let logger: Logger
  let swiftOutputDirectory: String
  let javaOutputDirectory: String

  var javaPackagePath: String {
    javaPackage.replacingOccurrences(of: ".", with: "/")
  }

  var thunkNameRegistry = ThunkNameRegistry()

  /// Because we need to write empty files for SwiftPM, keep track which files we didn't write yet,
  /// and write an empty file for those.
  var expectedOutputSwiftFiles: Set<String>

  package init(
    translator: Swift2JavaTranslator,
    javaPackage: String,
    swiftOutputDirectory: String,
    javaOutputDirectory: String
  ) {
    self.logger = Logger(label: "jni-generator", logLevel: translator.log.logLevel)
    self.analysis = translator.result
    self.swiftModuleName = translator.swiftModuleName
    self.javaPackage = javaPackage
    self.swiftOutputDirectory = swiftOutputDirectory
    self.javaOutputDirectory = javaOutputDirectory

     // If we are forced to write empty files, construct the expected outputs
    if translator.config.writeEmptyFiles ?? false {
      self.expectedOutputSwiftFiles = Set(translator.inputs.compactMap { (input) -> String? in
        guard let filePathPart = input.filePath.split(separator: "/\(translator.swiftModuleName)/").last else {
          return nil
        }

        return String(filePathPart.replacing(".swift", with: "+SwiftJava.swift"))
      })
      self.expectedOutputSwiftFiles.insert("\(translator.swiftModuleName)Module+SwiftJava.swift")
    } else {
      self.expectedOutputSwiftFiles = []
    }
  }

  func generate() throws {
    try writeSwiftThunkSources()
    try writeExportedJavaSources()

    let pendingFileCount = self.expectedOutputSwiftFiles.count
    if pendingFileCount > 0 {
      print("[swift-java] Write empty [\(pendingFileCount)] 'expected' files in: \(swiftOutputDirectory)/")
      try writeSwiftExpectedEmptySources()
    }
  }
}

extension SwiftType {
  var javaType: JavaType {
    switch self {
    case .nominal(let nominalType):
      if let knownType = nominalType.nominalTypeDecl.knownStandardLibraryType {
        guard let javaType = knownType.javaType else {
          fatalError("unsupported known type: \(knownType)")
        }
        return javaType
      }

      fatalError("unsupported nominal type: \(nominalType)")

    case .tuple([]):
      return .void

    case .metatype, .optional, .tuple, .function:
      fatalError("unsupported type: \(self)")
    }
  }
}

extension SwiftStandardLibraryTypeKind {
  var javaType: JavaType? {
    switch self {
    case .bool: .boolean
    case .int: .long  // TODO: Handle 32-bit or 64-bit
    case .int8: .byte
    case .uint16: .char
    case .int16: .short
    case .int32: .int
    case .int64: .long
    case .float: .float
    case .double: .double
    case .void: .void
    case .string: .javaLangString
    case .uint, .uint8, .uint32, .uint64,
      .unsafeRawPointer, .unsafeMutableRawPointer,
      .unsafePointer, .unsafeMutablePointer,
      .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer,
      .unsafeBufferPointer, .unsafeMutableBufferPointer:
      nil
    }
  }
}
