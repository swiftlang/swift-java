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
struct JExtractDefaultBuildConfiguration: BuildConfiguration {
  static let shared = JExtractDefaultBuildConfiguration()

  private var base: StaticBuildConfiguration

  init() {
    let decoder = JSONDecoder()
    do {
      base = try decoder.decode(StaticBuildConfiguration.self, from: StaticBuildConfiguration.embedded)
    } catch {
      fatalError("Embedded StaticBuildConfiguration is broken! data: \(String(data: StaticBuildConfiguration.embedded, encoding: .utf8) ?? "")")
    }
  }

  func isCustomConditionSet(name: String) throws -> Bool {
    base.isCustomConditionSet(name: name)
  }

  func hasFeature(name: String) throws -> Bool {
    base.hasFeature(name: name)
  }

  func hasAttribute(name: String) throws -> Bool {
    base.hasAttribute(name: name)
  }

  func canImport(importPath: [(TokenSyntax, String)], version: CanImportVersion) throws -> Bool {
    try base.canImport(importPath: importPath, version: version)
  }

  func isActiveTargetOS(name: String) throws -> Bool {
    true
  }

  func isActiveTargetArchitecture(name: String) throws -> Bool {
    true
  }

  func isActiveTargetEnvironment(name: String) throws -> Bool {
    true
  }

  func isActiveTargetRuntime(name: String) throws -> Bool {
    true
  }

  func isActiveTargetPointerAuthentication(name: String) throws -> Bool {
    true
  }

  func isActiveTargetObjectFormat(name: String) throws -> Bool {
    true
  }

  var targetPointerBitWidth: Int {
    base.targetPointerBitWidth
  }

  var targetAtomicBitWidths: [Int] {
    base.targetAtomicBitWidths
  }

  var endianness: Endianness {
    base.endianness
  }

  var languageVersion: VersionTuple {
    base.languageVersion
  }

  var compilerVersion: VersionTuple {
    base.compilerVersion
  }
}

extension BuildConfiguration where Self == JExtractDefaultBuildConfiguration {
  static var jextractDefault: JExtractDefaultBuildConfiguration {
    .shared
  }
}
