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
        public static org.swift.swiftkit.core.tuple.Tuple2<java.lang.Long, java.lang.String> returnPair() {
          long[] result_0$ = new long[1];
          java.lang.String[] result_1$ = new java.lang.String[1];
          SwiftModule.$returnPair(result_0$, result_1$);
          return new org.swift.swiftkit.core.tuple.Tuple2<java.lang.Long, java.lang.String>(result_0$[0], result_1$[0]);
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
        public static void takePair(org.swift.swiftkit.core.tuple.Tuple2<java.lang.Long, java.lang.String> arg) {
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

  @Test("Labelled tuple return (JNI)")
  func labeledTuple_javaBindings_jni() throws {
    try assertOutput(
      input: source,
      .jni,
      .java,
      expectedChunks: [
        """
        public static LabeledTuple_labeledTuple_x_y<java.lang.Integer, java.lang.Integer> labeledTuple() {
        """,
        """
        private static native void $labeledTuple(int[] result_0$, int[] result_1$);
        """,
        """
        public static final class LabeledTuple_labeledTuple_x_y<T0, T1> extends org.swift.swiftkit.core.tuple.Tuple2<T0, T1> {
        """,
        """
        public LabeledTuple_labeledTuple_x_y(T0 param0, T1 param1) { super(param0, param1); }
        """,
        """
        public T0 x() { return $0; }
        """,
        """
        public T1 y() { return $1; }
        """,
      ]
    )
  }

  @Test("Labelled tuple return, Swift thunks (JNI)")
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

  @Test
  func genericTuple() throws {
    let input = """
      public struct Box<T> {}
      public func genericTuple() -> (Box<Bool>, Box<String>) {
        fatalError()
      }
      """

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        org.swift.swiftkit.core._OutSwiftGenericInstance result_0$ = new org.swift.swiftkit.core._OutSwiftGenericInstance();
        org.swift.swiftkit.core._OutSwiftGenericInstance result_1$ = new org.swift.swiftkit.core._OutSwiftGenericInstance();
        SwiftModule.$genericTuple(result_0$, result_1$);
        """,
        """
        private static native void $genericTuple(org.swift.swiftkit.core._OutSwiftGenericInstance result_0$Out, org.swift.swiftkit.core._OutSwiftGenericInstance result_1$Out);
        """,
      ]
    )
  }

  @Test
  func singleTuple() throws {
    let input = """
      public func singleTuple(input: (String)) -> (String) {
        input
      }
      """

    try assertOutput(
      input: input,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        private static native java.lang.String $singleTuple(java.lang.String input);
        """
      ]
    )

    try assertOutput(
      input: input,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public func Java_com_example_swift_SwiftModule__00024singleTuple__Ljava_lang_String_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, input: jstring?) -> jstring? {
          return SwiftModule.singleTuple(input: String(fromJNI: input, in: environment)).getJNILocalRefValue(in: environment)
        } 
        """
      ]
    )
  }
}
