//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftJavaConfigurationShared
import Testing

@Suite
struct GradleDependencyParsingTests {

  @Test
  func parseSingleDependency() throws {
    let inputString = "com.example:thing:12.2"
    let parsed: JavaDependencyDescriptor = parseDependencyDescriptor(inputString)!

    #expect(parsed.groupID == "com.example")
    #expect(parsed.artifactID == "thing")
    #expect(parsed.version == "12.2")
  }

  @Test
  func parseMultiple() throws {
    let inputString = "com.example:thing:12.2,com.example:another:1.2.3-beta.1,"
    let parsed: [JavaDependencyDescriptor] = parseDependencyDescriptors(inputString)

    #expect(parsed.count == 2)
    #expect(parsed[0].groupID == "com.example")
    #expect(parsed[0].artifactID == "thing")
    #expect(parsed[0].version == "12.2")
    #expect(parsed[1].groupID == "com.example")
    #expect(parsed[1].artifactID == "another")
    #expect(parsed[1].version == "1.2.3-beta.1")
  }
}

