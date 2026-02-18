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
struct SwiftJavaConfigurationTests {

  @Test
  func parseJSONWithComments() throws {
    let config = try readConfiguration(
      string:
        """
        // some comments
        {
          // anywhere is ok
          "classpath": ""
        }
        """,
      configPath: nil
    )
  }
}
