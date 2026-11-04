//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftExtract
import SwiftJavaConfigurationShared
import SwiftSyntax

public func makeSwiftJavaAnalyzer(config: Configuration) -> SwiftAnalyzer {
  SwiftAnalyzer(
    config: config,
    extractDecider: JavaExtractDecider(
      accessLevel: config.effectiveMinimumInputAccessLevelMode,
      exportMode: config.effectiveExportMode,
      logLevel: config.logLevel ?? .info
    ),
  )
}

/// Java-specific per-decl extraction policy
///
/// In addition to the configured access-level filter, the Java target:
///
/// - Skips initializers of unspecialized generic types
/// - Force-extracts decls annotated `@JavaExport` even if they would
///   otherwise be filtered by access level
/// - Skips decls annotated `@JavaExport(false)`, or inside a type or extension
///   annotated `@JavaExport(false)`
/// - With the `annotated` export mode, extracts only decls annotated
///   `@JavaExport`, inside a type or extension annotated `@JavaExport`, or
///   types with such a member
/// - Skips Swift wrappers of Java types (`@JavaClass`, `@JavaInterface`,
///   `@JavaField`, `@JavaStaticField`, `@JavaMethod`, `@JavaStaticMethod`,
///   `@JavaImplementation`) since those are bridged the other way
/// - Skips Swift operators (`+`, `-`, prefix/postfix forms) — Java has no
///   operator-overload syntax, so the generator can't render them
public struct JavaExtractDecider: ExtractDecider {
  public let accessLevel: AccessLevelMode
  public let exportMode: JExtractExportMode
  let log: Logger

  public init(accessLevel: AccessLevelMode = .default, exportMode: JExtractExportMode = .default, logLevel: LogLevel = .info) {
    self.accessLevel = accessLevel
    self.exportMode = exportMode
    self.log = Logger(label: "JavaExtractDecider", logLevel: logLevel)
  }

  public func shouldExtract(
    decl: DeclSyntax,
    in parent: ExtractedNominalType?
  ) -> Bool {
    // Initializers of an unspecialized generic type can't be constructed from
    // Java — drop them regardless of attribute or access level.
    if let parent,
      decl.is(InitializerDeclSyntax.self),
      parent.swiftNominal.isGeneric,
      !parent.isSpecialization
    {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': initializer of an unspecialized generic type")
      return false
    }

    switch decl.javaExportMarker {
    case true?:
      return true
    case false?:
      log.trace("Skip '\(decl.qualifiedNameForDebug)': annotated @JavaExport(false)")
      return false
    case nil:
      break
    }
    let attrs = decl.asProtocol((any WithAttributesSyntax).self)?.attributes
    if attrs?.contains(where: { $0.isJavaKitMacro }) == true {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': swift-java macro-wrapped Java type")
      return false
    }

    // Swift prefix and postfix operators have no Java mapping. A declaration's operator name is
    // lexed as a binary operator, so only the `prefix` or `postfix` modifier tells them apart.
    if let fn = decl.as(FunctionDeclSyntax.self),
      fn.modifiers.contains(where: { $0.name.tokenKind == .keyword(.prefix) || $0.name.tokenKind == .keyword(.postfix) })
    {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': operators are not supported on Java")
      return false
    }

    let inheritedMarker = decl.inheritedJavaExportMarker
    if inheritedMarker == false {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': inside a declaration annotated @JavaExport(false)")
      return false
    }

    guard let mod = decl.asProtocol((any WithModifiersSyntax).self) else {
      return false
    }
    guard mod.isAtLeast(accessLevel, in: parent) else {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': not at least \(accessLevel)")
      return false
    }

    if exportMode == .annotated, inheritedMarker != true, !decl.containsJavaExportedMember {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': not annotated @JavaExport (exportMode: annotated)")
      return false
    }
    return true
  }

  public func mayExtractMembers(of extensionDecl: ExtensionDeclSyntax) -> Bool {
    switch extensionDecl.javaExportMarker ?? extensionDecl.inheritedJavaExportMarker {
    case true?: true
    case false?: false
    case nil: exportMode == .all || extensionDecl.containsJavaExportedMember
    }
  }
}
