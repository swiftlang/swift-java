//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

@_spi(Testing) import JExtractSwift
import SwiftSyntax
import SwiftParser
import Testing

@Suite("Nominal type lookup")
struct NominalTypeLookupSuite {
  func checkNominalRoundTrip(
    _ resolution: NominalTypeResolution,
    name: String,
    fileID: String = #fileID,
    filePath: String = #filePath,
    line: Int = #line,
    column: Int = #column
  ) {
    let sourceLocation = SourceLocation(fileID: fileID, filePath: filePath, line: line, column: column)
    let nominal = resolution.resolveNominalType(name)
    #expect(nominal != nil, sourceLocation: sourceLocation)
    if let nominal {
      #expect(resolution.fullyQualifiedName(of: nominal) == name, sourceLocation: sourceLocation)
    }
  }

  @Test func lookupBindingTests() {
    let resolution = NominalTypeResolution()
    resolution.addSourceFile("""
      extension X {
        struct Y {
        }
      }

      struct X {
      }

      extension X.Y {
        struct Z { }
      }
      """)

    // Bind all extensions and verify that all were bound.
    #expect(resolution.bindExtensions().isEmpty)

    checkNominalRoundTrip(resolution, name: "X")
    checkNominalRoundTrip(resolution, name: "X.Y")
    checkNominalRoundTrip(resolution, name: "X.Y.Z")
    #expect(resolution.resolveNominalType("Y") == nil)
    #expect(resolution.resolveNominalType("X.Z") == nil)
  }
}

