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

@Suite
final class InternalExtractTests {
  @Test("Import: internal decl if configured")
  func internalScope() throws {
    var config = Configuration()
    config.minimumInputAccessLevelMode = .internal

    let text =
      """
      internal func catchMeIfYouCan()
      func catchMeIfYouCan2()
      """

    try assertOutput(
      input: text,
      config: config,
      .ffm,
      .java,
      detectChunkByInitialLines: 2,
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
        """
        public static void catchMeIfYouCan2() {
          swiftjava_SwiftModule_catchMeIfYouCan2.call();
        }
        """,
      ]
    )
  }

  @Test("Import: package decl if configured")
  func packageScope() throws {
    var config = Configuration()
    config.minimumInputAccessLevelMode = .package

    let text =
      """
      package func catchMeIfYouCan()
      func skipMe()
      internal func skipMe2()
      """

    try assertOutput(
      input: text,
      config: config,
      .ffm,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * package func catchMeIfYouCan()
         * }
         */
        public static void catchMeIfYouCan() {
          swiftjava_SwiftModule_catchMeIfYouCan.call();
        }
        """
      ],
      notExpectedChunks: [
        """
        public static void skipMe() {
        """,
        """
        public static void skipMe2() {
        """,
      ]
    )
  }
}
