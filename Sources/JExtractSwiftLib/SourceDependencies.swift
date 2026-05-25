//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJavaConfigurationShared
import SwiftParser
import SwiftSyntax

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif


package typealias SwiftModuleName = String
package typealias SwiftTypeName = String
package typealias SwiftSourceText = String
package typealias JavaClassName = String
package typealias JavaFullyQualifiedClassName = String
package typealias JavaPackageName = String

/// Holds the inputs jextract needs for symbol resolution but does not generate
/// bindings for.
///
/// Two flavours of "dependency" are tracked:
/// - Wrapped Java classes referenced from this module's API (e.g. `JavaInteger`).
/// - Real Swift sources from dependency Swift modules (passed via `--depends-on`),
///   parsed once and registered as imported `SwiftModuleSymbolTable`s so that
///   cross-module type references in this module's API can resolve them.
package struct SourceDependencies {
  /// Swift wrapper type names for Java classes referenced from this module's
  /// API (by convention `Java<ClassName>`, e.g. `JavaVector`).
  package var javaClasses: [SwiftTypeName] = []

  /// Parsed Swift inputs from dependency modules, keyed by Swift module name.
  package var swiftModuleInputs: [SwiftModuleName: [SwiftJavaInputFile]] = [:]

  package init() {}

  /// Names of all dependency modules with associated Swift sources.
  package var swiftModuleNames: Dictionary<SwiftModuleName, [SwiftJavaInputFile]>.Keys {
    swiftModuleInputs.keys
  }

  package mutating func loadSwiftSources(from dependency: DependencyConfig, log: Logger) {
    guard let moduleName = dependency.swiftModuleName else {
      log.debug(
        "Skipping anonymous '--depends-on' entry (no '<Module>=' prefix); cross-module type references from it cannot be resolved."
      )
      return
    }
    guard !dependency.swiftSourcePaths.isEmpty else {
      log.warning(
        "Dependency module '\(moduleName)' has no resolvable Swift sources; cross-module type references will fail to import. Pass an explicit '--depends-on \(moduleName)=<config>,<sources>' or set 'inputSwiftDirectory' in its swift-java.config."
      )
      return
    }

    let files = collectAllFiles(
      suffix: ".swift",
      in: dependency.swiftSourcePaths,
      log: log,
    )
    var inputs: [SwiftJavaInputFile] = []
    let fm = FileManager.default
    for url in files where canExtract(from: url) {
      guard
        let data = fm.contents(atPath: url.path),
        let text = String(data: data, encoding: .utf8)
      else { continue }
      let syntax = Parser.parse(source: text)
      inputs.append(SwiftJavaInputFile(syntax: syntax, path: url.path))
    }

    if inputs.isEmpty {
      log.warning(
        "Dependency module '\(moduleName)' source paths \(dependency.swiftSourcePaths.map(\.path)) contained no extractable .swift files."
      )
      return
    }
    log.info(
      "Loaded \(inputs.count) source file(s) for dependency module '\(moduleName)' from \(dependency.swiftSourcePaths.map(\.path))"
    )
    swiftModuleInputs[moduleName] = inputs
  }
}
