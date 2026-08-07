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

import JavaKitExample
import SwiftJava
import Testing

@Suite
struct JavaRecordRuntimeTests {

  let jvm = try JavaKitSampleJVM.shared

  @Test
  func constructAndReadComponents() throws {
    let env = try jvm.environment()

    let p = Point(3, 4, environment: env)
    #expect(p.x() == 3)
    #expect(p.y() == 4)
  }

  @Test
  func equalityAndHashUseRecordContract() throws {
    let env = try jvm.environment()

    let a = Point(1, 2, environment: env)
    let b = Point(1, 2, environment: env)
    let c = Point(1, 3, environment: env)

    #expect(a.equals(b.as(JavaObject.self)) == true)
    #expect(a.equals(c.as(JavaObject.self)) == false)
    #expect(a.hashCode() == b.hashCode())
  }

  @Test
  func toStringMatchesRecordCanonicalForm() throws {
    let env = try jvm.environment()

    let p = Point(7, 9, environment: env)
    // Java record toString is `TypeName[comp1=v1, comp2=v2]`.
    #expect(p.toString() == "Point[x=7, y=9]")
  }
}
