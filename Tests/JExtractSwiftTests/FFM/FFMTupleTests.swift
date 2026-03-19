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

/// FFM tuple binding tests, aligned with `JNITupleTests` where lowering allows it.
///
/// JNI uses `(Int64, String)` for `returnPair` / `takePair`; FFM `lowerResult` does not support
/// `String` in tuple results yet, so those signatures use `(Int64, Int64)` here.
@Suite
struct FFMTupleTests {
  let source = """
    public func returnPair() -> (Int64, Int64)
    public func takePair(_ arg: (Int64, Int64))
    public func labeledTuple() -> (x: Int32, y: Int32)
    """

  @Test
  func returnPair_javaBindings() throws {
    try assertOutput(
      input: source,
      .ffm,
      .java,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.tuple.Tuple2<Long, Long> returnPair() {
          try(var arena$ = Arena.ofConfined()) {
            MemorySegment _result_0 = arena$.allocate(SwiftValueLayout.SWIFT_INT64);
            MemorySegment _result_1 = arena$.allocate(SwiftValueLayout.SWIFT_INT64);
            swiftjava_SwiftModule_returnPair.call(_result_0, _result_1);
            return new org.swift.swiftkit.core.tuple.Tuple2<>(_result_0.get(SwiftValueLayout.SWIFT_INT64, 0), _result_1.get(SwiftValueLayout.SWIFT_INT64, 0));
          }
        }
        """,
      ]
    )
  }

  @Test
  func takePair_javaBindings() throws {
    try assertOutput(
      input: source,
      .ffm,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static void takePair(org.swift.swiftkit.core.tuple.Tuple2<Long, Long> arg) {
          swiftjava_SwiftModule_takePair__.call(arg.$0, arg.$1);
        }
        """,
      ]
    )
  }

  @Test
  func labeledTuple_javaBindings() throws {
    try assertOutput(
      input: source,
      .ffm,
      .java,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.tuple.Tuple2<Integer, Integer> labeledTuple() {
        """,
        """
            return new org.swift.swiftkit.core.tuple.Tuple2<>(_result_0.get(SwiftValueLayout.SWIFT_INT32, 0), _result_1.get(SwiftValueLayout.SWIFT_INT32, 0));
        """,
      ]
    )
  }

  @Test
  func returnPair_swiftThunks() throws {
    try assertOutput(
      input: source,
      .ffm,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let _result = returnPair()
        _result_0.initialize(to: _result.0)
        _result_1.initialize(to: _result.1)
        """,
      ]
    )
  }

  @Test
  func takePair_swiftThunks() throws {
    try assertOutput(
      input: source,
      .ffm,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        takePair((arg_0, arg_1))
        """,
      ]
    )
  }

  @Test
  func labeledTuple_swiftThunks() throws {
    try assertOutput(
      input: source,
      .ffm,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        let _result = labeledTuple()
        _result_0.initialize(to: _result.0)
        _result_1.initialize(to: _result.1)
        """,
      ]
    )
  }
}
