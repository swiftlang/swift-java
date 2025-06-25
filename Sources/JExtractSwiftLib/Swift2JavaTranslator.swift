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
import JavaTypes
import SwiftBasicFormat
import SwiftParser
import JavaKitConfigurationShared
import SwiftSyntax

/// Takes swift interfaces and translates them into Java used to access those.
public final class Swift2JavaTranslator {
  static let SWIFT_INTERFACE_SUFFIX = ".swiftinterface"

  package var log = Logger(label: "translator", logLevel: .info)

  let config: Configuration

  // ==== Input

  struct Input {
    let filePath: String
    let syntax: SourceFileSyntax
  }

  var inputs: [Input] = []

  // ==== Output state

  package var importedGlobalVariables: [ImportedFunc] = []

  package var importedGlobalFuncs: [ImportedFunc] = []

  /// A mapping from Swift type names (e.g., A.B) over to the imported nominal
  /// type representation.
  package var importedTypes: [String: ImportedNominalType] = [:]

  package var swiftStdlibTypeDecls: SwiftStandardLibraryTypeDecls

  package let symbolTable: SwiftSymbolTable

  /// The name of the Swift module being translated.
  var swiftModuleName: String {
    symbolTable.moduleName
  }

  public init(
    config: Configuration
  ) {
    guard let swiftModule = config.swiftModule else {
      fatalError("Missing 'swiftModule' name.") // FIXME: can we make it required in config? but we shared config for many cases
    }
    self.config = config
    self.symbolTable = SwiftSymbolTable(parsedModuleName: swiftModule)

    // Create a mock of the Swift standard library.
    var parsedSwiftModule = SwiftParsedModuleSymbolTable(moduleName: "Swift")
    self.swiftStdlibTypeDecls = SwiftStandardLibraryTypeDecls(into: &parsedSwiftModule)
    self.symbolTable.importedModules.append(parsedSwiftModule.symbolTable)
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
  }

  package func prepareForTranslation() {
    /// Setup the symbol table.
    symbolTable.setup(inputs.map({ $0.syntax }))
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
    if !nominalNode.shouldImport(log: log) {
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
    guard let swiftType = try? SwiftType(typeNode, symbolTable: self.symbolTable) else {
      return nil
    }
    guard let swiftNominalDecl = swiftType.asNominalTypeDeclaration else {
      return nil
    }

    // Whether to import this extension?
    guard let nominalNode = symbolTable.parsedModule.nominalTypeSyntaxNodes[swiftNominalDecl] else {
      return nil
    }
    guard nominalNode.shouldImport(log: log) else {
      return nil
    }

    return importedNominalType(swiftNominalDecl)
  }

  func importedNominalType(_ nominal: SwiftNominalTypeDeclaration) -> ImportedNominalType? {
    let fullName = nominal.qualifiedName

    if let alreadyImported = importedTypes[fullName] {
      return alreadyImported
    }

    let importedNominal = ImportedNominalType(swiftNominal: nominal)

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
