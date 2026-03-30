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
struct JNITupleTests {
  let source =
    """
    public func returnPair() -> (Int64, String)
    public func takePair(_ arg: (Int64, String))
    public func labeledTuple() -> (x: Int32, y: Int32)
    """

  @Test
  func returnPair_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.tuple.Tuple2<Long, String> returnPair() {
          long[] result_0$ = new long[1];
          java.lang.String[] result_1$ = new java.lang.String[1];
          SwiftModule.$returnPair(result_0$, result_1$);
          return new org.swift.swiftkit.core.tuple.Tuple2<>(result_0$[0], result_1$[0]);
        }
        """,
        """
        private static native void $returnPair(long[] result_0$, java.lang.String[] result_1$);
        """,
      ]
    )
  }

  @Test
  func returnPair_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let tupleResult$ = SwiftModule.returnPair()
        var element_0_jni$ = tupleResult$.0.getJNILocalRefValue(in: environment)
        environment.interface.SetLongArrayRegion(environment, result_0$, 0, 1, &element_0_jni$)
        let element_1_jni$ = tupleResult$.1.getJNILocalRefValue(in: environment)
        environment.interface.SetObjectArrayElement(environment, result_1$, 0, element_1_jni$)
        """
      ]
    )
  }

  @Test
  func takePair_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static void takePair(org.swift.swiftkit.core.tuple.Tuple2<Long, String> arg) {
          SwiftModule.$takePair(arg.$0, arg.$1);
        }
        """,
        """
        private static native void $takePair(long arg_0, java.lang.String arg_1);
        """,
      ]
    )
  }

  @Test
  func takePair_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        SwiftModule.takePair((Int64(fromJNI: arg_0, in: environment), String(fromJNI: arg_1, in: environment)))
        """
      ]
    )
  }

  @Test
  func labeledTuple_javaBindings() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.tuple.Tuple2<Integer, Integer> labeledTuple() {
        """,
        """
        private static native void $labeledTuple(int[] result_0$, int[] result_1$);
        """,
      ]
    )
  }

  @Test
  func labeledTuple_swiftThunks() throws {
    try assertOutput(
      input: source,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let tupleResult$ = SwiftModule.labeledTuple()
        var element_0_jni$ = tupleResult$.x.getJNILocalRefValue(in: environment)
        environment.interface.SetIntArrayRegion(environment, result_0$, 0, 1, &element_0_jni$)
        var element_1_jni$ = tupleResult$.y.getJNILocalRefValue(in: environment)
        environment.interface.SetIntArrayRegion(environment, result_1$, 0, 1, &element_1_jni$)
        """
      ]
    )
  }
}
