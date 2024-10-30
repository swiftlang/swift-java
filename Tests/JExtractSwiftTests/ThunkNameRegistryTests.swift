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

import JExtractSwift
import Testing

final class ThunkNameRegistryTests {
  @Test("Thunk names: deduplicate names")
  func deduplicate() throws {
    var registry = ThunkNameRegistry()
    #expect(registry.deduplicate(name: "swiftjava_hello") == "swiftjava_hello")
    #expect(registry.deduplicate(name: "swiftjava_hello") == "swiftjava_hello$1")
    #expect(registry.deduplicate(name: "swiftjava_hello") == "swiftjava_hello$2")
    #expect(registry.deduplicate(name: "swiftjava_hello") == "swiftjava_hello$3")
    #expect(registry.deduplicate(name: "swiftjava_other") == "swiftjava_other")
    #expect(registry.deduplicate(name: "swiftjava_other") == "swiftjava_other$1")
  }
}