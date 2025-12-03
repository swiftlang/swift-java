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

final class ByteArrayTests {
  let text =
    """
    public func acceptArray(array: [UInt8])
    """


  @Test(
    "Import: accept [UInt8] array",
    arguments: [
      // TODO: implement JNI mode here
      (
        JExtractGenerationMode.ffm,
        /* expected Java chunks */
        [
          """
          /**
           * {@snippet lang=c :
           * void swiftjava_SwiftModule_acceptArray_array(const void *array_pointer, ptrdiff_t array_count)
           * }
           */
          private static class swiftjava_SwiftModule_acceptArray_array {
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
              /* array_pointer: */SwiftValueLayout.SWIFT_POINTER,
              /* array_count: */SwiftValueLayout.SWIFT_INT
            );
          """,
          """
            /**
             * Downcall to Swift:
             * {@snippet lang=swift :
             * public func acceptArray(array: [UInt8])
             * }
             */
            public static void acceptArray(byte[] array) {
              try(var arena$ = Arena.ofConfined()) {
                swiftjava_SwiftModule_acceptArray_array.call(arena$.allocateFrom(ValueLayout.JAVA_BYTE, array), array.length);
              }
            }
            """
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("swiftjava_SwiftModule_acceptArray_array")
          public func swiftjava_SwiftModule_acceptArray_array(_ array_pointer: UnsafeRawPointer, _ array_count: Int) {
            acceptArray(array: [UInt8](UnsafeRawBufferPointer(start: array_pointer, count: array_count)))
          }
          """
        ]
      )
    ]
  )
  func func_accept_array_uint8(mode: JExtractGenerationMode, expectedJavaChunks: [String], expectedSwiftChunks: [String]) throws {
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