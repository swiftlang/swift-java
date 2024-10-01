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

import JavaTypes
import Testing

@Suite
struct ManglingTests {

  @Test
  func methodMangling() throws {
    let demangledSignature = try MethodSignature(
      mangledName: "(ILjava/lang/String;[I)J"
    )
    let expectedSignature = MethodSignature(
      resultType: .long,
      parameterTypes: [
        .int,
        .class(package: "java.lang", name: "String"),
        .array(.int),
      ]
    )
    #expect(demangledSignature == expectedSignature)
    #expect(expectedSignature.mangledName == "(ILjava/lang/String;[I)J")
  }
}
