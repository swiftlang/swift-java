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

import CodePrinting
import SwiftExtract
import SwiftJavaConfigurationShared
import SwiftJavaJNICore

/// A table that where keys are Swift class names and the values are
/// the fully qualified canoical names.
package typealias JavaClassLookupTable = [String: String]

/// A table where keys are Swift module names and the values are Java package names.
package typealias ModuleJavaPackages = [String: String]

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
  let moduleJavaPackages: ModuleJavaPackages

  var javaPackagePath: String {
    javaPackage.replacingOccurrences(of: ".", with: "/")
  }

  var thunkNameRegistry = ThunkNameRegistry()

  /// Accumulates every ``@_cdecl`` symbol name emitted during thunk printing.
  /// Written to a linker version script after generation when
  /// ``Configuration/linkerExportListOutput`` is set.
  var generatedCDeclSymbolNames: [String] = []

  /// Cached Java translation result. 'nil' indicates failed translation.
  var translatedDecls: [ExtractedFunc: TranslatedFunctionDecl] = [:]
  var translatedEnumCases: [ExtractedEnumCase: TranslatedEnumCase] = [:]
  var interfaceProtocolWrappers: [ExtractedNominalType: JavaInterfaceSwiftWrapper] = [:]

  /// Protocols that should be boxed to support returning them as `any P / some P`
  private(set) var existentialProtocolBoxes: [ExtractedNominalType] = []

  /// Duplicate identifier tracking for the current batch of methods being generated.
  var currentJavaIdentifiers: JavaIdentifierFactory = JavaIdentifierFactory()

  /// Because we need to write empty files for SwiftPM, keep track which files we didn't write yet,
  /// and write an empty file for those.
  ///
  /// Since Swift files in SwiftPM builds needs to be unique, we use this fact to flatten paths into plain names here.
  /// For uniqueness checking "did we write this file already", just checking the name should be sufficient.
  var expectedOutputSwiftFileNames: Set<String>

  package init(
    config: Configuration,
    translator: SwiftAnalyzer,
    javaPackage: String,
    swiftOutputDirectory: String,
    javaOutputDirectory: String,
    javaClassLookupTable: JavaClassLookupTable,
    moduleJavaPackages: ModuleJavaPackages,
  ) {
    self.config = config
    self.logger = Logger(label: "jni-generator", logLevel: translator.log.logLevel)
    self.analysis = translator.result
    self.swiftModuleName = translator.swiftModuleName
    self.javaPackage = javaPackage
    self.swiftOutputDirectory = swiftOutputDirectory
    self.javaOutputDirectory = javaOutputDirectory
    self.javaClassLookupTable = javaClassLookupTable
    self.moduleJavaPackages = moduleJavaPackages
    self.lookupContext = translator.lookupContext

    // If we are forced to write empty files, construct the expected outputs.
    // It is sufficient to use file names only, since SwiftPM requires names to be unique within a module anyway.
    if config.effectiveWriteEmptyFiles {
      self.expectedOutputSwiftFileNames = Set(
        translator.inputs.compactMap { (input) -> String? in
          guard let fileName = input.path.split(separator: PATH_SEPARATOR).last else {
            return nil
          }
          if fileName.hasSuffix(".swift") {
            return String(fileName.replacing(".swift", with: "+SwiftJava.swift"))
          } else if fileName.hasSuffix(".swiftinterface") {
            return String(fileName.replacing(".swiftinterface", with: "+SwiftJava.swift"))
          }
          return nil
        }
      )
      // Also include filtered-out files so SwiftPM gets the empty outputs it expects
      for path in translator.filteredOutPaths {
        guard let fileName = path.split(separator: PATH_SEPARATOR).last else {
          continue
        }
        if fileName.hasSuffix(".swift") {
          self.expectedOutputSwiftFileNames.insert(
            String(fileName.replacing(".swift", with: "+SwiftJava.swift"))
          )
        }
      }
      self.expectedOutputSwiftFileNames.insert("\(translator.swiftModuleName)Module+SwiftJava.swift")
      self.expectedOutputSwiftFileNames.insert("Foundation+SwiftJava.swift")
    } else {
      self.expectedOutputSwiftFileNames = []
    }

    if config.enableJavaCallbacks ?? false {
      // We translate all the protocol wrappers
      // as we need them to know what protocols we can allow the user to implement themselves
      // in Java.
      self.interfaceProtocolWrappers = self.generateInterfaceWrappers(Array(self.analysis.extractedTypes.values))
    }

    // Every extracted protocol that also gets a plain Java `interface`
    // generated for it is eligible to be boxed as an existential.
    self.existentialProtocolBoxes = self.analysis.extractedTypes.values
      .filter { $0.swiftNominal.kind == .protocol }
      .sorted { $0.swiftNominal.qualifiedName < $1.swiftNominal.qualifiedName }
  }

  func generate() throws {
    try writeSwiftThunkSources()
    try writeExportedJavaSources()
    try writeLinkerExportList()

    let pendingFileCount = self.expectedOutputSwiftFileNames.count
    if pendingFileCount > 0 {
      print("[swift-java] Write empty [\(pendingFileCount)] 'expected' files in: \(swiftOutputDirectory)/")
      try writeSwiftExpectedEmptySources()
    }
  }
}

extension JNISwift2JavaGenerator {
  static func indirectVariableName(for parameterName: String) -> String {
    "\(parameterName)$indirect"
  }

  func inheritedProtocols(of type: ExtractedNominalType) -> [ExtractedNominalType] {
    type.inheritedTypes
      .compactMap(\.asNominalTypeDeclaration)
      .filter { $0.kind == .protocol }
      .compactMap {
        self.analysis.extractedTypes[$0.qualifiedName]
      }
  }

  /// The direct (non-inherited) requirements of `type` (a protocol) that are
  /// wrappable on the Java side: instance methods and variable accessors
  /// (getters/setters), excluding statics and anything whose signature
  /// doesn't translate (e.g. referencing `Self`/associated types).
  func supportedProtocolRequirements(of type: ExtractedNominalType) -> [ExtractedFunc] {
    (type.methods + type.variables).filter { requirement in
      !requirement.isStatic && self.translatedDecl(for: requirement) != nil
    }
  }

  /// All wrappable requirements for `type` (a protocol), including those
  /// inherited from refined protocols — the transitive closure of
  /// `supportedProtocolRequirements(of:)`. Used to build an existential
  /// box's method bodies and per-requirement `@_cdecl` dispatch thunks,
  /// since the box must implement everything the protocol (directly or
  /// transitively) requires.
  func allProtocolRequirementMethods(of type: ExtractedNominalType) -> [ExtractedFunc] {
    var visited: Set<ObjectIdentifier> = []
    var queue: [ExtractedNominalType] = [type]
    var methods: [ExtractedFunc] = []
    while let current = queue.popLast() {
      guard visited.insert(ObjectIdentifier(current)).inserted else { continue }
      methods.append(contentsOf: self.supportedProtocolRequirements(of: current))
      queue.append(contentsOf: inheritedProtocols(of: current))
    }
    return methods
  }
}
