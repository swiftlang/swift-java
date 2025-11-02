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
import Testing

@Suite
struct JNIJavaKitTests {
  let source =
    """
    public func function(javaLong: JavaLong, javaInteger: JavaInteger, int: Int64) {}
    """

  let classLookupTable = [
    "JavaLong": "java.lang.Long",
    "JavaInteger": "java.lang.Integer"
  ]

  @Test
  func function_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * public func function(javaLong: JavaLong, javaInteger: JavaInteger, int: Int64)
       * }
       */
      public static void function(java.lang.Long javaLong, java.lang.Integer javaInteger, long int) {
        SwiftModule.$function(javaLong, javaInteger, int);
      }
      """,
      """
      private static native void $function(java.lang.Long javaLong, java.lang.Integer javaInteger, long int);
      """
      ]
    )
  }

  @Test
  func function_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      javaClassLookupTable: classLookupTable,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024function__Ljava_lang_Long_2Ljava_lang_Integer_2J")
        func Java_com_example_swift_SwiftModule__00024function__Ljava_lang_Long_2Ljava_lang_Integer_2J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, javaLong: jobject?, javaInteger: jobject?, int: jlong) {
          guard let javaLong_unwrapped$ = javaLong else {
            fatalError("javaLong was null in call to \\(#function), but Swift requires non-optional!")
          }
          guard let javaInteger_unwrapped$ = javaInteger else {
            fatalError("javaInteger was null in call to \\(#function), but Swift requires non-optional!")
          }
          SwiftModule.function(javaLong: JavaLong(javaThis: javaLong_unwrapped$, environment: environment), javaInteger: JavaInteger(javaThis: javaInteger_unwrapped$, environment: environment), int: Int64(fromJNI: int, in: environment))
        }
        """
      ]
    )
  }
}
