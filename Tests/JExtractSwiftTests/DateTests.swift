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
  @Test(
    "Import: accept Date",
    arguments: [
      (
        JExtractGenerationMode.jni,
        /* expected Java chunks */
        [
          """
          public static void acceptDate(java.time.Instant date) {
            SwiftModule.$acceptDate((date.getEpochSecond() + (date.getNano() / 1_000_000_000.0)));
          }
          """,
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024acceptDate__D")
          func Java_com_example_swift_SwiftModule__00024acceptDate__D(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, date: jdouble) {
            SwiftModule.acceptDate(date: Date.init(timeIntervalSince1970: Double(fromJNI: date, in: environment)))
          }
          """
        ],
      )
    ]
  )
  func func_accept_date(mode: JExtractGenerationMode, expectedJavaChunks: [String], expectedSwiftChunks: [String]) throws {
    let text =
      """
      import Foundation
      
      public func acceptDate(date: Date)
      """

    try assertOutput(
      input: text, 
      mode, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: expectedJavaChunks)
      
      try assertOutput(
      input: text, 
      mode, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: expectedSwiftChunks)
  }  
  
  @Test(
    "Import: return Date",
    arguments: [
      (
        JExtractGenerationMode.jni,
        /* expected Java chunks */
        [
          """
          public static java.time.Instant returnDate() {
            double $instant = SwiftModule.$returnDate();
            long $seconds = (long) $instant;
            long $nanos = (long) (($instant - $seconds) * 1_000_000_000);
            return java.time.Instant.ofEpochSecond($seconds, $nanos);
          }
          """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024returnDate__")
          func Java_com_example_swift_SwiftModule__00024returnDate__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jdouble {
            return SwiftModule.returnDate().timeIntervalSince1970.getJNIValue(in: environment)
          }
          """
        ]
      )
    ]
  )
  func func_return_Date(mode: JExtractGenerationMode, expectedJavaChunks: [String], expectedSwiftChunks: [String]) throws {
    let text =
      """
      import Foundation
      public func returnDate() -> Date
      """
    
    try assertOutput(
      input: text, 
      mode, .java,
      expectedChunks: expectedJavaChunks)
      
      try assertOutput(
      input: text, 
      mode, .swift,
      expectedChunks: expectedSwiftChunks)
  }
}
