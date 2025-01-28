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
import SwiftSyntax

/// Takes swift interfaces and translates them into Java used to access those.
public final class Swift2JavaTranslator {
  static let SWIFT_INTERFACE_SUFFIX = ".swiftinterface"

  package var log = Logger(label: "translator", logLevel: .info)

  // ==== Output configuration
  let javaPackage: String

  var javaPackagePath: String {
    javaPackage.replacingOccurrences(of: ".", with: "/")
  }

  // ==== Output state

  package var importedGlobalFuncs: [ImportedFunc] = []

  /// A mapping from Swift type names (e.g., A.B) over to the imported nominal
  /// type representation.
  package var importedTypes: [String: ImportedNominalType] = [:]

  var swiftStdlibTypes: SwiftStandardLibraryTypes

  let symbolTable: SwiftSymbolTable
  let nominalResolution: NominalTypeResolution = NominalTypeResolution()

  var thunkNameRegistry: ThunkNameRegistry = ThunkNameRegistry()

  /// The name of the Swift module being translated.
  var swiftModuleName: String {
    symbolTable.moduleName
  }

  public init(
    javaPackage: String,
    swiftModuleName: String
  ) {
    self.javaPackage = javaPackage
    self.symbolTable = SwiftSymbolTable(parsedModuleName: swiftModuleName)

    // Create a mock of the Swift standard library.
    var parsedSwiftModule = SwiftParsedModuleSymbolTable(moduleName: "Swift")
    self.swiftStdlibTypes = SwiftStandardLibraryTypes(into: &parsedSwiftModule)
    self.symbolTable.importedModules.append(parsedSwiftModule.symbolTable)
  }
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Analysis

extension Swift2JavaTranslator {
  /// The primitive Java type to use for Swift's Int type, which follows the
  /// size of a pointer.
  ///
  /// FIXME: Consider whether to extract this information from the Swift
  /// interface file, so that it would be 'int' for 32-bit targets or 'long' for
  /// 64-bit targets but make the Java code different for the two, vs. adding
  /// a checked truncation operation at the Java/Swift board.
  var javaPrimitiveForSwiftInt: JavaType { .long }

  public func analyze(
    file: String,
    text: String? = nil
  ) throws {
    guard text != nil || FileManager.default.fileExists(atPath: file) else {
      throw Swift2JavaTranslatorError(message: "Missing input file: \(file)")
    }

    log.trace("Analyze: \(file)")
    let text = try text ?? String(contentsOfFile: file)

    try analyzeSwiftInterface(interfaceFilePath: file, text: text)

    log.debug("Done processing: \(file)")
  }

  package func analyzeSwiftInterface(interfaceFilePath: String, text: String) throws {
    let sourceFileSyntax = Parser.parse(source: text)

    addSourceFile(sourceFileSyntax)
    prepareForTranslation()

    let visitor = Swift2JavaVisitor(
      moduleName: self.swiftModuleName,
      targetJavaPackage: self.javaPackage,
      translator: self
    )
    visitor.walk(sourceFileSyntax)
  }

  package func addSourceFile(_ sourceFile: SourceFileSyntax) {
    nominalResolution.addSourceFile(sourceFile)
  }

  package func prepareForTranslation() {
    nominalResolution.bindExtensions()

    for (_, node) in nominalResolution.topLevelNominalTypes {
      symbolTable.parsedModule.addNominalTypeDeclaration(node, parent: nil)
    }

    for (ext, nominalNode) in nominalResolution.resolvedExtensions {
      guard let nominalDecl = symbolTable.parsedModule.lookup(nominalNode) else {
        continue
      }

      symbolTable.parsedModule.addExtension(ext, extending: nominalDecl)
    }
  }
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Defaults

extension Swift2JavaTranslator {
  /// Default formatting options.
  static let defaultFormat = BasicFormat(indentationWidth: .spaces(2))

  /// Default set Java imports for every generated file
  static let defaultJavaImports: Array<String> = [
    "org.swift.swiftkit.*",
    "org.swift.swiftkit.SwiftKit",
    "org.swift.swiftkit.util.*",

    // Necessary for native calls and type mapping
    "java.lang.foreign.*",
    "java.lang.invoke.*",
    "java.util.Arrays",
    "java.util.stream.Collectors",
    "java.util.concurrent.atomic.*",
    "java.nio.charset.StandardCharsets",
  ]

}

// ==== ----------------------------------------------------------------------------------------------------------------
// MARK: Type translation
extension Swift2JavaTranslator {
  /// Try to resolve the given nominal type node into its imported
  /// representation.
  func importedNominalType(
    _ nominal: some DeclGroupSyntax & NamedDeclSyntax
  ) -> ImportedNominalType? {
    if !nominal.shouldImport(log: log) {
      return nil
    }

    guard let fullName = nominalResolution.fullyQualifiedName(of: nominal) else {
      return nil
    }

    if let alreadyImported = importedTypes[fullName] {
      return alreadyImported
    }

    // Determine the nominal type kind.
    let kind: NominalTypeKind
    switch Syntax(nominal).as(SyntaxEnum.self) {
    case .actorDecl:  kind = .actor
    case .classDecl:  kind = .class
    case .enumDecl:   kind = .enum
    case .structDecl: kind = .struct
    default: return nil
    }

    let importedNominal = ImportedNominalType(
      swiftTypeName: fullName,
      javaType: .class(
        package: javaPackage,
        name: fullName
      ),
      kind: kind
    )

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
