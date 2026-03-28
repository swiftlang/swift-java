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
import Testing

@Suite
struct FFMThrowingTests {
  let throwingSource = """
    public func throwingVoid() throws
    public func throwingReturn(x: Int64) throws -> Int64
    """

  @Test
  func throwingVoid_swiftThunks() throws {
    try assertOutput(
      input: throwingSource,
      .ffm,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_throwingVoid")
        public func swiftjava_SwiftModule_throwingVoid(_ _errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>) {
          do {
            try throwingVoid()
          } catch {
            _errorOut.pointee = Unmanaged.passRetained(SwiftJavaError(error)).toOpaque()
          }
        }
        """
      ]
    )
  }

  @Test
  func throwingReturn_swiftThunks() throws {
    try assertOutput(
      input: throwingSource,
      .ffm,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_throwingReturn_x")
        public func swiftjava_SwiftModule_throwingReturn_x(_ x: Int64, _ _errorOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> Int64 {
          do {
            return try throwingReturn(x: x)
          } catch {
            _errorOut.pointee = Unmanaged.passRetained(SwiftJavaError(error)).toOpaque()
            return 0
          }
        }
        """
      ]
    )
  }

  @Test
  func throwingVoid_javaBindings() throws {
    try assertOutput(
      input: throwingSource,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static void throwingVoid() throws SwiftJavaError {
        """,
        """
        MemorySegment _errorOut = arena$.allocate(ValueLayout.ADDRESS);
        """,
        """
        _errorOut.set(ValueLayout.ADDRESS, 0, MemorySegment.NULL);
        """,
        """
        if (!_errorOut.get(ValueLayout.ADDRESS, 0).equals(MemorySegment.NULL)) {
        """,
      ]
    )
  }

  @Test
  func throwingReturn_javaBindings() throws {
    try assertOutput(
      input: throwingSource,
      .ffm,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static long throwingReturn(long x) throws SwiftJavaError {
        """,
        """
        MemorySegment _errorOut = arena$.allocate(ValueLayout.ADDRESS);
        """,
        """
        if (!_errorOut.get(ValueLayout.ADDRESS, 0).equals(MemorySegment.NULL)) {
        """,
      ]
    )
  }

  let stringReturnSource = """
    public func greeting() -> String
    """

  @Test
  func stringReturn_swiftThunks() throws {
    try assertOutput(
      input: stringReturnSource,
      .ffm,
      .swift,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        @_cdecl("swiftjava_SwiftModule_greeting")
        public func swiftjava_SwiftModule_greeting() -> UnsafeMutablePointer<Int8> {
          return _swiftjava_stringToCString(greeting())
        }
        """
      ]
    )
  }

  @Test
  func stringReturn_javaBindings() throws {
    try assertOutput(
      input: stringReturnSource,
      .ffm,
      .java,
      expectedChunks: [
        """
        public static java.lang.String greeting() {
        """,
        """
        return SwiftRuntime.fromCString(
        """,
      ]
    )
  }
}
