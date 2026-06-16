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

import OrderedCollections
import SwiftExtract
import SwiftJavaConfigurationShared
import SwiftParser
import SwiftSyntax

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension SourceDependencies {
  /// Inject synthetic `@JavaClass public class <Name> {}` stubs so the symbol
  /// table can resolve Java wrapper types referenced in the Swift API.
  package mutating func addJavaWrapperStubs(_ javaClasses: [SwiftTypeName]) {
    guard !javaClasses.isEmpty else { return }
    let text =
      javaClasses
      .map { "@JavaClass public class \($0) {}" }
      .joined(separator: "\n")
    let stub = SwiftInputFile(syntax: SwiftParser.Parser.parse(source: text), path: "<javaClassStubs>.swift")
    syntheticStubInputs["<javaClassStubs>"] = [stub]
  }

  /// Load Swift sources from a dependency module described by `dependency` and
  /// register them in `swiftModuleInputs` for cross-module type resolution.
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
    var inputs: [SwiftInputFile] = []
    let fm = FileManager.default
    for url in files where canExtract(from: url) {
      guard
        let data = fm.contents(atPath: url.path),
        let text = String(data: data, encoding: .utf8)
      else { continue }
      let syntax = SwiftParser.Parser.parse(source: text)
      inputs.append(SwiftInputFile(syntax: syntax, path: url.path))
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
