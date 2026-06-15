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
import Testing

@Suite("SwiftSyntheticTypes")
struct SwiftSyntheticTypesSuite {

  // ==== ----------------------------------------------------------------------
  // MARK: unresolvedNominal stamps the placeholder flag

  @Test func unresolvedNominalIsMarkedAsPlaceholder() {
    let type = SwiftSyntheticTypes.unresolvedNominal("Element")

    #expect(type.isUnresolvedTypePlaceholder)
    #expect(type.asNominalTypeDeclaration?.isUnresolvedTypePlaceholder == true)
    #expect("\(type)" == "Element")

    // Module name is empty — there's no real declaring module — and that's
    // the honest answer; callers that want to recognize placeholders read
    // `isUnresolvedTypePlaceholder`, not the moduleName string.
    #expect(type.asNominalTypeDeclaration?.moduleName == "")
  }

  // ==== ----------------------------------------------------------------------
  // MARK: Real source-derived nominals don't carry the flag

  @Test func realNominalIsNotMarkedAsPlaceholder() throws {
    let result = try analyze(
      sources: [
        ("/fake/Source.swift", "public struct Tank {}")
      ],
      moduleName: "Aquarium"
    )

    let tank = try #require(result.extractedTypes["Tank"])
    #expect(!tank.swiftType.isUnresolvedTypePlaceholder)
    #expect(tank.swiftNominal.isUnresolvedTypePlaceholder == false)
  }
}
