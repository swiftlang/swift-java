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
    extractDecider: JavaExtractDecider(accessLevel: config.swiftExtractAccessLevel),
  )
}

/// Java-specific per-decl extraction policy
///
/// In addition to the configured access-level filter, the Java target:
///
/// - Force-extracts decls annotated `@JavaExport` even if they would
///   otherwise be filtered by access level
/// - Skips Swift wrappers of Java types (`@JavaClass`, `@JavaInterface`,
///   `@JavaField`, `@JavaStaticField`, `@JavaMethod`, `@JavaStaticMethod`,
///   `@JavaImplementation`) since those are bridged the other way
/// - Skips Swift operators (`+`, `-`, prefix/postfix forms) — Java has no
///   operator-overload syntax, so the generator can't render them
public struct JavaExtractDecider: ExtractDecider {
  public let accessLevel: AccessLevelMode

  public init(accessLevel: AccessLevelMode = .default) {
    self.accessLevel = accessLevel
  }

  public func shouldExtract(
    decl: DeclSyntax,
    in parent: ExtractedNominalType?,
    log: Logger
  ) -> Bool {
    let attrs = decl.asProtocol((any WithAttributesSyntax).self)?.attributes
    if attrs?.contains(where: { $0.isJavaExport }) == true {
      return true
    }
    if attrs?.contains(where: { $0.isSwiftJavaMacro }) == true {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': swift-java macro-wrapped Java type")
      return false
    }

    // Swift operators have no Java mapping
    if let fn = decl.as(FunctionDeclSyntax.self) {
      switch fn.name.tokenKind {
      case .binaryOperator, .prefixOperator, .postfixOperator:
        log.trace("Skip '\(decl.qualifiedNameForDebug)': operators are not supported on Java")
        return false
      default:
        break
      }
    }

    guard let mod = decl.asProtocol((any WithModifiersSyntax).self) else {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': not a modifier-bearing decl")
      return false
    }
    let ok = mod.passesAccessLevel(accessLevel, in: parent)
    if !ok {
      log.trace("Skip '\(decl.qualifiedNameForDebug)': not at least \(accessLevel)")
    }
    return ok
  }
}
