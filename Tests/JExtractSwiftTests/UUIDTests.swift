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

struct UUIDTests {
  @Test(
    "Import: accept UUID",
    arguments: [
      (
        JExtractGenerationMode.jni,
        /* expected Java chunks */
        [
          """
          public static void acceptUUID(java.util.UUID uuid) {
            SwiftModule.$acceptUUID(uuid.toString());
          }
          """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024acceptUUID__Ljava_lang_String_2")
          public func Java_com_example_swift_SwiftModule__00024acceptUUID__Ljava_lang_String_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, uuid: jstring?) {
            guard let uuid_unwrapped$ = UUID.init(uuidString: String(fromJNI: uuid, in: environment)) else {
              fatalError("Invalid UUID passed from Java")
            }
            SwiftModule.acceptUUID(uuid: uuid_unwrapped$)
          }
          """
        ],
      )
    ]
  )
  func func_accept_uuid(mode: JExtractGenerationMode, expectedJavaChunks: [String], expectedSwiftChunks: [String]) throws {
    let text =
      """
      import Foundation
      
      public func acceptUUID(uuid: UUID)
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
    "Import: return UUID",
    arguments: [
      (
        JExtractGenerationMode.jni,
        /* expected Java chunks */
        [
          """
          public static java.util.UUID returnUUID() {
            return java.util.UUID.fromString(SwiftModule.$returnUUID());
          }
          """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("Java_com_example_swift_SwiftModule__00024returnUUID__")
          public func Java_com_example_swift_SwiftModule__00024returnUUID__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jstring? {
            return SwiftModule.returnUUID().uuidString.getJNIValue(in: environment)
          }
          """
        ]
      )
    ]
  )
  func func_return_UUID(mode: JExtractGenerationMode, expectedJavaChunks: [String], expectedSwiftChunks: [String]) throws {
    let text =
      """
      import Foundation
      public func returnUUID() -> UUID
      """
    
    try assertOutput(
      input: text, 
      mode, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: expectedJavaChunks
    )

      try assertOutput(
      input: text, 
      mode, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: expectedSwiftChunks)
  }
}
