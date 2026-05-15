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

/// Holds the inputs jextract needs for symbol resolution but does not generate
/// bindings for.
///
/// Two flavours of "dependency" are tracked:
/// - Wrapped Java classes referenced from this module's API (e.g. `JavaInteger`),
///   exposed back to the symbol table as synthetic `@JavaClass public class X {}`
///   stubs by ``Swift2JavaTranslator/buildDependencyClassesSourceFile``.
/// - Real Swift sources from dependent Swift modules (passed via `--depends-on`),
///   parsed once and registered as imported `SwiftModuleSymbolTable`s so that
///   cross-module type references in this module's API can resolve them.
package final class SourceDependencies {
  /// Java class names referenced from this module that live in wrapped Java
  /// dependencies.
  package var javaClasses: [String] = []

  /// Parsed Swift inputs from dependent modules, keyed by Swift module name.
  package private(set) var swiftModuleInputs: [SwiftModuleName: [SwiftJavaInputFile]] = [:]

  package init() {}

  /// Replace the parsed Swift inputs for a dependent module.
  package func setSwiftSources(_ inputs: [SwiftJavaInputFile], for moduleName: SwiftModuleName) {
    swiftModuleInputs[moduleName] = inputs
  }

  /// Names of all dependent modules with associated Swift sources.
  package var swiftModuleNames: Dictionary<SwiftModuleName, [SwiftJavaInputFile]>.Keys {
    swiftModuleInputs.keys
  }

  /// Walk a single dependent module's resolved source paths and parse every
  /// `.swift` file into a `SwiftJavaInputFile`, registering the result on this
  /// resolver. Anonymous `--depends-on` entries and modules with no resolvable
  /// sources are skipped with a warning, so the user has a clear signal when
  /// cross-module lookups will fail.
  package func loadSwiftSources(from dependency: DependentConfig, log: Logger) {
    guard let moduleName = dependency.swiftModuleName else {
      log.warning(
        "Skipping anonymous '--depends-on' entry (no '<Module>=' prefix); cross-module type references from it cannot be resolved."
      )
      return
    }
    guard !dependency.swiftSourcePaths.isEmpty else {
      log.warning(
        "Dependent module '\(moduleName)' has no resolvable Swift sources; cross-module type references will fail to import. Pass an explicit '--depends-on \(moduleName)=<config>,<sources>' or set 'inputSwiftDirectory' in its swift-java.config."
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
        "Dependent module '\(moduleName)' source paths \(dependency.swiftSourcePaths.map(\.path)) contained no extractable .swift files."
      )
      return
    }
    log.info(
      "Loaded \(inputs.count) source file(s) for dependent module '\(moduleName)' from \(dependency.swiftSourcePaths.map(\.path))"
    )
    setSwiftSources(inputs, for: moduleName)
  }
}
