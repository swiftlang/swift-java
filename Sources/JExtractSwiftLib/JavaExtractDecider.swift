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
/// - Skips Swift wrappers of Java types (`@JavaClass`, `@JavaInterface`,
///   `@JavaField`, `@JavaStaticField`, `@JavaMethod`, `@JavaStaticMethod`,
///   `@JavaImplementation`) since those are bridged the other way
/// - Skips Swift operators (`+`, `-`, prefix/postfix forms) — Java has no
///   operator-overload syntax, so the generator can't render them
public struct JavaExtractDecider: ExtractDecider {
  public let accessLevel: AccessLevelMode
  let log: Logger

  public init(accessLevel: AccessLevelMode = .default, logLevel: LogLevel = .info) {
    self.accessLevel = accessLevel
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

    let attrs = decl.asProtocol((any WithAttributesSyntax).self)?.attributes
    if attrs?.contains(where: { $0.isJavaExport }) == true {
      return true
    }
    if attrs?.contains(where: { $0.isJavaKitMacro }) == true {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': swift-java macro-wrapped Java type")
      return false
    }

    // Swift operators have no Java mapping
    if let fn = decl.as(FunctionDeclSyntax.self) {
      switch fn.name.tokenKind {
      case .binaryOperator(let symbol):
        // Allow only supported operators
        if symbol == "+" {
          break
        }
        log.trace("Skip '\(decl.qualifiedNameForDebug)': operators are not supported on Java")
        return false
      case .prefixOperator, .postfixOperator:
        log.trace("Skip '\(decl.qualifiedNameForDebug)': operators are not supported on Java")
        return false
      default:
        break
      }
    }

    guard let mod = decl.asProtocol((any WithModifiersSyntax).self) else {
      return false
    }
    let ok = mod.isAtLeast(accessLevel, in: parent)
    if !ok {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': not at least \(accessLevel)")
    }
    return ok
  }
}
