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

  /// Module-qualified identities of extracted types that are surfaced to Java as `SwiftError` exceptions.
  lazy var swiftErrorTypes: Set<SwiftNominalIdentity> = Set(
    analysis.extractedTypes.values
      .filter { isSwiftErrorType($0) }
      .map(\.swiftNominal.identity)
  )
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
    let analysis = translator.result
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
          guard let fileName = input.path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last else {
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
        guard let fileName = path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last else {
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

    // Expand variadic functions into N overloads
    var expandedAnalysis = analysis
    expandedAnalysis.expandVariadicOverloads(maxOverloads: config.effectiveMaxVariadicOverloads)
    self.analysis = expandedAnalysis

    // Every extracted protocol that also gets a plain Java `interface`
    // generated for it is eligible to be boxed as an existential.
    self.existentialProtocolBoxes = expandedAnalysis.extractedTypes.values
      .filter { $0.swiftNominal.kind == .protocol }
      .sorted { $0.swiftNominal.qualifiedName < $1.swiftNominal.qualifiedName }

    if config.effectiveEnableJavaCallbacks {
      // We translate all the protocol wrappers
      // as we need them to know what protocols we can allow the user to implement themselves
      // in Java.
      self.interfaceProtocolWrappers = self.generateInterfaceWrappers(Array(expandedAnalysis.extractedTypes.values))
    }
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

  /// Whether `type` conforms to `Error` and is surfaced to Java as a `SwiftError` subclass.
  ///
  /// Types that never get a Java class or bridge (protocols, unspecialized generics,
  /// specializations and case-less enums such as `Never`) are excluded.
  func isSwiftErrorType(_ type: ExtractedNominalType) -> Bool {
    guard type.swiftNominal.kind != .protocol else { return false }
    guard !type.swiftNominal.isGeneric, !type.isSpecialization else { return false }
    guard !(type.swiftNominal.kind == .enum && type.cases.isEmpty) else { return false }
    return type.conformsTo("Error", in: analysis.extractedTypes)
      || type.conformsTo("LocalizedError", in: analysis.extractedTypes)
  }

  /// Whether `type` is a class whose superclass is itself an error type, and therefore already
  /// inherits the generated `_JNIThrowableError` conformance (redeclaring it would not compile).
  ///
  /// Such errors are thrown to Java as their root error class, since the generated Java classes
  /// do not mirror Swift class inheritance.
  func inheritsThrowableErrorConformance(_ type: ExtractedNominalType) -> Bool {
    guard type.swiftNominal.kind == .class else { return false }
    return type.inheritedTypes.contains { inherited in
      guard let decl = inherited.asNominalTypeDeclaration, decl.kind == .class else { return false }
      return self.swiftErrorTypes.contains(decl.identity)
    }
  }

  /// The direct (non-inherited) requirements of `type` (a protocol) that are
  /// wrappable on the Java side: instance methods and variable accessors
  /// (getters/setters), excluding statics and anything whose signature
  /// doesn't translate (e.g. referencing `Self`/associated types).
  func supportedProtocolRequirements(of type: ExtractedNominalType) -> [ExtractedFunc] {
    uniqueProtocolRequirements(
      (type.methods + type.variables).filter { requirement in
        !requirement.isStatic && !requirement.isClass
          && (try? self.javaTranslator.translate(requirement)) != nil
      }
    )
  }

  /// Compare the callable signature rather than source text. A default
  /// implementation may use different access modifiers, local parameter names,
  /// default arguments, or a narrower throwing effect from the protocol
  /// requirement it implements.
  func uniqueProtocolRequirements(_ methods: [ExtractedFunc]) -> [ExtractedFunc] {
    var unique: [ExtractedFunc] = []
    for method in methods {
      let duplicate = unique.contains { existing in
        existing.apiKind == method.apiKind && existing.name == method.name
          && normalizedProtocolSignature(existing) == normalizedProtocolSignature(method)
      }
      if !duplicate {
        unique.append(method)
      }
    }
    return unique
  }

  private func normalizedProtocolSignature(_ method: ExtractedFunc) -> SwiftFunctionSignature {
    var signature = method.functionSignature
    signature.selfParameter = nil
    signature.effectSpecifiers.removeAll { $0 == .throws }
    signature.thrownTypedError = nil
    signature.parameters = signature.parameters.map { parameter in
      var parameter = parameter
      parameter.parameterName = nil
      parameter.hasDefaultValue = false
      parameter.defaultValueExpression = nil
      return parameter
    }
    return signature
  }

  /// All wrappable requirements for `type` (a protocol), including those
  /// inherited from refined protocols — the transitive closure of
  /// `supportedProtocolRequirements(of:)`. Used to build an existential
  /// box's method bodies and per-requirement `@_cdecl` dispatch thunks,
  /// since the box must implement everything the protocol (directly or
  /// transitively) requires.
  ///
  /// A protocol requirement and its default implementation are extracted as
  /// distinct ``ExtractedFunc`` instances. Keep the first occurrence so the
  /// box emits one JNI thunk and one Java method for each callable signature.
  func allProtocolRequirementMethods(of type: ExtractedNominalType) -> [ExtractedFunc] {
    var visited: Set<ObjectIdentifier> = []
    var queue: [ExtractedNominalType] = [type]
    var methods: [ExtractedFunc] = []
    while let current = queue.popLast() {
      guard visited.insert(ObjectIdentifier(current)).inserted else { continue }
      methods.append(contentsOf: self.supportedProtocolRequirements(of: current))
      queue.append(contentsOf: inheritedProtocols(of: current))
    }
    return uniqueProtocolRequirements(methods)
  }
}
