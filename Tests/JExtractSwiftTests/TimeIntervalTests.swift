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

import JExtractSwiftLib
import SwiftJavaConfigurationShared
import Testing

struct TimeIntervalTests {
  @Test(
    "Import: accept TimeInterval (resolves to Double)",
    arguments: [
      (
        JExtractGenerationMode.jni,
        /* expected Java chunks */
        [
          """
          public static void delay(double seconds) {
            SwiftModule.$delay(seconds);
          }
          """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024delay__D")
          public func Java_com_example_swift_SwiftModule__00024delay__D(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, seconds: jdouble) {
            SwiftModule.delay(seconds: Double(fromJNI: seconds, in: environment))
          }
          """
        ],
      )
    ]
  )
  func func_accept_timeInterval(
    mode: JExtractGenerationMode,
    expectedJavaChunks: [String],
    expectedSwiftChunks: [String]
  ) throws {
    let text =
      """
      import Foundation

      public func delay(seconds: TimeInterval)
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: expectedJavaChunks
    )

    try assertOutput(
      input: text,
      mode,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: expectedSwiftChunks
    )
  }

  @Test(
    "Import: return TimeInterval (resolves to Double)",
    arguments: [
      (
        JExtractGenerationMode.jni,
        /* expected Java chunks */
        [
          """
          public static double now() {
            return SwiftModule.$now();
          }
          """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024now__")
          public func Java_com_example_swift_SwiftModule__00024now__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jdouble {
            return SwiftModule.now()
          }
          """
        ]
      )
    ]
  )
  func func_return_timeInterval(
    mode: JExtractGenerationMode,
    expectedJavaChunks: [String],
    expectedSwiftChunks: [String]
  ) throws {
    let text =
      """
      import Foundation
      public func now() -> TimeInterval
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: expectedJavaChunks
    )

    try assertOutput(
      input: text,
      mode,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: expectedSwiftChunks
    )
  }
}
