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

import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

final class InternalExtractTests {
  let text =
    """
    internal func catchMeIfYouCan()
    """

  @Test("Import: internal decl if configured")
  func data_swiftThunk() throws {
    var config = Configuration()
    config.minimumInputAccessLevelMode = .internal

    try assertOutput(
      input: text,
      config: config,
      .ffm, .java,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * internal func catchMeIfYouCan()
         * }
         */
        public static void catchMeIfYouCan() {
          swiftjava_SwiftModule_catchMeIfYouCan.call();
        }
        """,
      ]
    )
  }
}