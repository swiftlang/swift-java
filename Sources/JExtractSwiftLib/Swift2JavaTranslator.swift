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
import SwiftBasicFormat
import SwiftParser
import SwiftJavaConfigurationShared
import SwiftSyntax

/// Takes swift interfaces and translates them into Java used to access those.
public final class Swift2JavaTranslator {
  static let SWIFT_INTERFACE_SUFFIX = ".swiftinterface"

  package var log: Logger

  let config: Configuration

  /// The name of the Swift module being translated.
  let swiftModuleName: String

  // ==== Input

  struct Input {
    let filePath: String
    let syntax: SourceFileSyntax
  }

  var inputs: [Input] = []

  /// A list of used Swift class names that live in dependencies, e.g. `JavaInteger`
  package var dependenciesClasses: [String] = []

  // ==== Output state

  package var importedGlobalVariables: [ImportedFunc] = []

  package var importedGlobalFuncs: [ImportedFunc] = []

  /// A mapping from Swift type names (e.g., A.B) over to the imported nominal
  /// type representation.
  package var importedTypes: [String: ImportedNominalType] = [:]

  var lookupContext: SwiftTypeLookupContext! = nil

  var symbolTable: SwiftSymbolTable! {
    return lookupContext?.symbolTable
  }

  public init(
    config: Configuration
  ) {
    guard let swiftModule = config.swiftModule else {
      fatalError("Missing 'swiftModule' name.") // FIXME: can we make it required in config? but we shared config for many cases
    }
    self.log = Logger(label: "translator", logLevel: config.logLevel ?? .info)
    self.config = config
    self.swiftModuleName = swiftModule
  }
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Analysis

extension Swift2JavaTranslator {
  var result: AnalysisResult {
    AnalysisResult(
      importedTypes: self.importedTypes,
      importedGlobalVariables: self.importedGlobalVariables,
      importedGlobalFuncs: self.importedGlobalFuncs
    )
  }

  package func add(filePath: String, text: String) {
    log.trace("Adding: \(filePath)")
    let sourceFileSyntax = Parser.parse(source: text)
    self.inputs.append(Input(filePath: filePath, syntax: sourceFileSyntax))
  }

  /// Convenient method for analyzing single file.
  package func analyze(
    file: String,
    text: String
  ) throws {
    self.add(filePath: file, text: text)
    try self.analyze()
  }

  /// Analyze registered inputs.
  func analyze() throws {
    prepareForTranslation()

    let visitor = Swift2JavaVisitor(translator: self)

    for input in self.inputs {
      log.trace("Analyzing \(input.filePath)")
      visitor.visit(sourceFile: input.syntax)
    }

    // If any API uses 'Foundation.Data', import 'Data' as if it's declared in
    // this module.
    if let dataDecl = self.symbolTable[.data] {
      let dataProtocolDecl = self.symbolTable[.dataProtocol]!
      if self.isUsing(where: { $0 == dataDecl || $0 == dataProtocolDecl }) {
        visitor.visit(nominalDecl: dataDecl.syntax!.asNominal!, in: nil)
      }
    }
  }

  package func prepareForTranslation() {
    let dependenciesSource = self.buildDependencyClassesSourceFile()

    let symbolTable = SwiftSymbolTable.setup(
      moduleName: self.swiftModuleName,
      inputs.map({ $0.syntax }) + [dependenciesSource],
      log: self.log
    )
    self.lookupContext = SwiftTypeLookupContext(symbolTable: symbolTable)
  }

  /// Check if any of the imported decls uses a nominal declaration that satisfies
  /// the given predicate.
  func isUsing(where predicate: (SwiftNominalTypeDeclaration) -> Bool) -> Bool {
    func check(_ type: SwiftType) -> Bool {
      switch type {
      case .nominal(let nominal):
        return predicate(nominal.nominalTypeDecl)
      case .optional(let ty):
        return check(ty)
      case .tuple(let tuple):
        return tuple.contains(where: check)
      case .function(let fn):
        return check(fn.resultType) || fn.parameters.contains(where: { check($0.type) })
      case .metatype(let ty):
        return check(ty)
      case .existential(let ty), .opaque(let ty):
        return check(ty)
      case .composite(let types):
        return types.contains(where: check)
      case .genericParameter:
        return false
      }
    }

    func check(_ fn: ImportedFunc) -> Bool {
      if check(fn.functionSignature.result.type) {
        return true
      }
      if fn.functionSignature.parameters.contains(where: { check($0.type) }) {
        return true
      }
      return false
    }

    if self.importedGlobalFuncs.contains(where: check) {
      return true
    }
    if self.importedGlobalVariables.contains(where: check) {
      return true
    }
    for importedType in self.importedTypes.values {
      if importedType.initializers.contains(where: check) {
        return true
      }
      if importedType.methods.contains(where: check) {
        return true
      }
      if importedType.variables.contains(where: check) {
        return true
      }
    }
    return false
  }

  /// Returns a source file that contains all the available dependency classes.
  private func buildDependencyClassesSourceFile() -> SourceFileSyntax {
    let contents = self.dependenciesClasses.map {
      "public class \($0) {}"
    }
    .joined(separator: "\n")

    return SourceFileSyntax(stringLiteral: contents)
  }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Type translation
extension Swift2JavaTranslator {
  /// Try to resolve the given nominal declaration node into its imported representation.
  func importedNominalType(
    _ nominalNode: some DeclGroupSyntax & NamedDeclSyntax & WithModifiersSyntax & WithAttributesSyntax,
    parent: ImportedNominalType?
  ) -> ImportedNominalType? {
    if !nominalNode.shouldExtract(config: config, log: log, in: parent) {
      return nil
    }

    guard let nominal = symbolTable.lookupType(nominalNode.name.text, parent: parent?.swiftNominal) else {
      return nil
    }
    return self.importedNominalType(nominal)
  }

  /// Try to resolve the given nominal type node into its imported representation.
  func importedNominalType(
    _ typeNode: TypeSyntax
  ) -> ImportedNominalType? {
    guard let swiftType = try? SwiftType(typeNode, lookupContext: lookupContext) else {
      return nil
    }
    guard let swiftNominalDecl = swiftType.asNominalTypeDeclaration else {
      return nil
    }

    // Whether to import this extension?
    guard swiftNominalDecl.moduleName == self.swiftModuleName else {
      return nil
    }
    guard swiftNominalDecl.syntax!.shouldExtract(config: config, log: log, in: nil) else {
      return nil
    }

    return importedNominalType(swiftNominalDecl)
  }

  func importedNominalType(_ nominal: SwiftNominalTypeDeclaration) -> ImportedNominalType? {
    let fullName = nominal.qualifiedName

    if let alreadyImported = importedTypes[fullName] {
      return alreadyImported
    }

    let importedNominal = try? ImportedNominalType(swiftNominal: nominal, lookupContext: lookupContext)

    importedTypes[fullName] = importedNominal
    return importedNominal
  }
}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Errors

public struct Swift2JavaTranslatorError: Error {
  let message: String

  public init(message: String) {
    self.message = message
  }
}
