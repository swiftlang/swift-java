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

import SwiftSyntax

extension SwiftAnalyzer {
  func visitFoundationDeclsIfNeeded(with visitor: SwiftAnalysisVisitor) {
    // Each entry pairs a Foundation/FoundationEssentials counterpart so the
    // user-code reference can match either. Entries within the same group are
    // visited together when any one of the candidates is referenced — so using
    // Data also emits DataProtocol, etc.
    struct FoundationTypeGroup {
      let candidates: [SwiftKnownTypeDeclKind]
      let fakeSourceFilePath: String
    }
    let groups: [[FoundationTypeGroup]] = [
      [
        .init(
          candidates: [.foundationData, .essentialsData],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_DATA.swift",
        ),
        .init(
          candidates: [.foundationDataProtocol, .essentialsDataProtocol],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_DATAPROTOCOL.swift",
        ),
      ],
      [
        .init(
          candidates: [.foundationDate, .essentialsDate],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_DATE.swift",
        )
      ],
      [
        .init(
          candidates: [.foundationUUID, .essentialsUUID],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_UUID.swift",
        )
      ],
      [
        .init(
          candidates: [.foundationURL, .essentialsURL],
          fakeSourceFilePath: "Foundation/FAKE_FOUNDATION_URL.swift",
        )
      ],
    ]

    for group in groups {
      let resolved: [(primary: SwiftNominalTypeDeclaration, source: String, candidates: [SwiftNominalTypeDeclaration])] =
        group.compactMap { type in
          let candidates = type.candidates.compactMap { self.symbolTable[$0] }
          guard let primary = candidates.first else {
            return nil
          }
          return (primary, type.fakeSourceFilePath, candidates)
        }
      guard !resolved.isEmpty else {
        continue
      }

      let allCandidates = resolved.flatMap(\.candidates)
      let isReferenced = self.isUsing(where: { decl in
        allCandidates.contains(where: { $0 === decl })
      })
      guard isReferenced else {
        continue
      }

      // Visit the fake source files, and register the types.
      for entry in resolved {
        visitor.visit(
          nominalDecl: entry.primary.syntax.asNominal!,
          in: nil,
          sourceFilePath: entry.source,
        )
      }
    }
  }
}
