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
          public static void acceptDate(Date date) {
            SwiftModule.$acceptDate(date.$memoryAddress());
          }
          """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024acceptDate__J")
          func Java_com_example_swift_SwiftModule__00024acceptDate__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, date: jlong) {
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
          public static Date returnDate(SwiftArena swiftArena$) {
          """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024returnDate__")
          func Java_com_example_swift_SwiftModule__00024returnDate__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
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

  @Test(
    "Import: Date type",
    arguments: [
      (
        JExtractGenerationMode.jni,
        /* expected Java chunks */
        [
          """
          public final class Date implements JNISwiftInstance {
          """,
          """
          public static Date init(double timeIntervalSince1970, SwiftArena swiftArena$) {
          """,
          """
          public double getTimeIntervalSince1970() {
          """,
          """
          public static Date fromInstant(java.time.Instant instant, SwiftArena swiftArena$) {
          """,
          """
          public java.time.Instant toInstant() {
          """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_Date__00024init__D")
          func Java_com_example_swift_Date__00024init__D(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, timeIntervalSince1970: jdouble) -> jlong {
          """,
          """
          @_cdecl("Java_com_example_swift_Date__00024getTimeIntervalSince1970__J")
          func Java_com_example_swift_Date__00024getTimeIntervalSince1970__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, self: jlong) -> jdouble {
          """
        ]
      )
    ]
  )
  func date_class(mode: JExtractGenerationMode, expectedJavaChunks: [String], expectedSwiftChunks: [String]) throws {
    let text =
      """
      import Foundation
      public func f() -> Date
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
