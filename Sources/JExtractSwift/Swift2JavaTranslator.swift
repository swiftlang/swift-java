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

  // ==== Input configuration
  let swiftModuleName: String

  // ==== Output configuration
  let javaPackage: String

  var javaPackagePath: String {
    javaPackage.replacingOccurrences(of: ".", with: "/")
  }

  // ==== Output state

  // TODO: consider how/if we need to store those etc
  public var importedGlobalFuncs: [ImportedFunc] = []

  /// A mapping from Swift type names (e.g., A.B) over to the imported nominal
  /// type representation.
  public var importedTypes: [String: ImportedNominalType] = [:]

  let nominalResolution: NominalTypeResolution = NominalTypeResolution()

  public init(
    javaPackage: String,
    swiftModuleName: String
  ) {
    self.javaPackage = javaPackage
    self.swiftModuleName = swiftModuleName
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
    swiftInterfacePath: String,
    text: String? = nil
  ) throws {
    if text == nil {
      precondition(
        swiftInterfacePath.hasSuffix(Self.SWIFT_INTERFACE_SUFFIX),
        "Swift interface path must end with \(Self.SWIFT_INTERFACE_SUFFIX), was: \(swiftInterfacePath)"
      )

      if !FileManager.default.fileExists(atPath: swiftInterfacePath) {
        throw Swift2JavaTranslatorError(message: "Missing input file: \(swiftInterfacePath)")
      }
    }

    log.trace("Analyze: \(swiftInterfacePath)")
    let text = try text ?? String(contentsOfFile: swiftInterfacePath)

    try analyzeSwiftInterface(interfaceFilePath: swiftInterfacePath, text: text)

    log.info("Done processing: \(swiftInterfacePath)")
  }

  package func analyzeSwiftInterface(interfaceFilePath: String, text: String) throws {
    assert(interfaceFilePath.hasSuffix(Self.SWIFT_INTERFACE_SUFFIX))

    let sourceFileSyntax = Parser.parse(source: text)

    // Find all of the types and extensions, then bind the extensions.
    nominalResolution.addSourceFile(sourceFileSyntax)
    nominalResolution.bindExtensions()

    let visitor = Swift2JavaVisitor(
      moduleName: self.swiftModuleName,
      targetJavaPackage: self.javaPackage,
      translator: self
    )
    visitor.walk(sourceFileSyntax)
  }

}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Defaults

extension Swift2JavaTranslator {
  /// Default formatting options.
  static let defaultFormat = BasicFormat(indentationWidth: .spaces(2))

  /// Default set Java imports for every generated file
  static let defaultJavaImports: Array<String> = [
    // Support library in Java
    "org.swift.swiftkit.SwiftKit",

    // Necessary for native calls and type mapping
    "java.lang.foreign.*",
    "java.lang.invoke.*",
    "java.util.Arrays",
    "java.util.stream.Collectors",
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
      swiftMangledName: nominal.mangledNameFromComment,
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
