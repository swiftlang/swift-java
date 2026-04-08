//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
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

struct DateTests {
  @Test("Import: accept Date")
  func func_accept_date() throws {
    let text =
      """
      import Foundation

      public func acceptDate(date: Date)
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
          """
          public static void acceptDate(org.swift.swiftkit.core.foundation.Date date) {
            SwiftModule.$acceptDate(date.$memoryAddress());
          }
          """
      ]
    )

    try assertOutput(
      input: text,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024acceptDate__J")
          public func Java_com_example_swift_SwiftModule__00024acceptDate__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, date: jlong) {
          """
      ]
    )
  }

  @Test("Import: return Date")
  func func_return_Date() throws {
    let text =
      """
      import Foundation
      public func returnDate() -> Date
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      expectedChunks: [
          """
          public static org.swift.swiftkit.core.foundation.Date returnDate(SwiftArena swiftArena) {
          """
      ],
    )

    try assertOutput(
      input: text,
      .jni,
      .swift,
      expectedChunks: [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024returnDate__")
          public func Java_com_example_swift_SwiftModule__00024returnDate__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
          """
      ]
    )
  }
}
