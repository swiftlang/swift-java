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

import Foundation
import SwiftIfConfig
import SwiftSyntax

/// A default, fixed build configuration during static analysis for interface extraction.
package struct SwiftExtractDefaultBuildConfiguration: BuildConfiguration {
  package static let shared = SwiftExtractDefaultBuildConfiguration()

  private var base: StaticBuildConfiguration

  package init() {
    guard let url = Bundle.module.url(forResource: "static-build-config", withExtension: "json") else {
      fatalError("static-build-config.json is not found in module bundle")
    }
    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      base = try decoder.decode(StaticBuildConfiguration.self, from: data)
    } catch {
      fatalError("\(error)")
    }
  }

  package func isCustomConditionSet(name: String) throws -> Bool {
    base.isCustomConditionSet(name: name)
  }

  package func hasFeature(name: String) throws -> Bool {
    base.hasFeature(name: name)
  }

  package func hasAttribute(name: String) throws -> Bool {
    base.hasAttribute(name: name)
  }

  package func canImport(importPath: [(TokenSyntax, String)], version: CanImportVersion) throws -> Bool {
    try base.canImport(importPath: importPath, version: version)
  }

  package func isActiveTargetOS(name: String) throws -> Bool {
    true
  }

  package func isActiveTargetArchitecture(name: String) throws -> Bool {
    true
  }

  package func isActiveTargetEnvironment(name: String) throws -> Bool {
    true
  }

  package func isActiveTargetRuntime(name: String) throws -> Bool {
    true
  }

  package func isActiveTargetPointerAuthentication(name: String) throws -> Bool {
    true
  }

  package func isActiveTargetObjectFormat(name: String) throws -> Bool {
    true
  }

  package var targetPointerBitWidth: Int {
    base.targetPointerBitWidth
  }

  package var targetAtomicBitWidths: [Int] {
    base.targetAtomicBitWidths
  }

  package var endianness: Endianness {
    base.endianness
  }

  package var languageVersion: VersionTuple {
    base.languageVersion
  }

  package var compilerVersion: VersionTuple {
    base.compilerVersion
  }
}

extension BuildConfiguration where Self == SwiftExtractDefaultBuildConfiguration {
  package static var swiftExtractDefault: SwiftExtractDefaultBuildConfiguration {
    .shared
  }
}
