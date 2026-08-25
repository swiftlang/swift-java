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
struct JNIPointerTests {
  let pointerSource =
    """
    public struct MyStruct {
      public var x: Int32 = 0
    }

    public func globalTakeUnsafePointer(p: UnsafePointer<MyStruct>) {}
    """

  let bufferPointerSource =
    """
    public func globalTakeUnsafeBufferPointer(buffer: UnsafeBufferPointer<Int32>) {}
    """

  let returnPointerSource =
    """
    public struct MyStruct {
      public var x: Int32 = 0
    }

    public func globalReturnUnsafePointer() -> UnsafePointer<MyStruct> {
      fatalError()
    }
    """

  let returnBufferPointerSource =
    """
    public func globalReturnUnsafeBufferPointer() -> UnsafeBufferPointer<Int32> {
      fatalError()
    }
    """

  let rawBufferPointerSource =
    """
    public func globalTakeUnsafeRawBufferPointer(buffer: UnsafeRawBufferPointer) {}
    """

  let returnRawBufferPointerSource =
    """
    public func globalReturnUnsafeRawBufferPointer() -> UnsafeRawBufferPointer {
      fatalError()
    }
    """

  @Test
  func takeUnsafePointer_javaBindings() throws {
    try assertOutput(
      input: pointerSource,
      .jni,
      .java,
      expectedChunks: [
        "public static void globalTakeUnsafePointer(long p) {",
        "private static native void $globalTakeUnsafePointer(long p);",
      ]
    )
  }

  @Test
  func takeUnsafePointer_swiftThunks() throws {
    try assertOutput(
      input: pointerSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024globalTakeUnsafePointer__J")
        public func Java_com_example_swift_SwiftModule__00024globalTakeUnsafePointer__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, p: jlong) {
          assert(p != 0, "p memory address was null")
          let pBits$ = Int(Int64(fromJNI: p, in: environment))
          let p$ = UnsafeMutablePointer<MyStruct>(bitPattern: pBits$)
          guard let p$ else {
            fatalError("p memory address was null in call to \\(#function)!")
          }
          SwiftModule.globalTakeUnsafePointer(p: p$)
        }
        """
      ]
    )
  }

  @Test
  func takeUnsafeBufferPointer_javaBindings() throws {
    try assertOutput(
      input: bufferPointerSource,
      .jni,
      .java,
      expectedChunks: [
        "public static void globalTakeUnsafeBufferPointer(org.swift.swiftkit.core.SwiftUnsafeBufferPointer buffer) {",
        "private static native void $globalTakeUnsafeBufferPointer(long buffer, long buffer_count);",
      ]
    )
  }

  @Test
  func takeUnsafeBufferPointer_swiftThunks() throws {
    try assertOutput(
      input: bufferPointerSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024globalTakeUnsafeBufferPointer__JJ")
        public func Java_com_example_swift_SwiftModule__00024globalTakeUnsafeBufferPointer__JJ(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, buffer: jlong, buffer_count: jlong) {
          let bufferBits$ = Int(Int64(fromJNI: buffer, in: environment))
          let buffer$ = UnsafeMutablePointer<Int32>(bitPattern: bufferBits$)
          SwiftModule.globalTakeUnsafeBufferPointer(buffer: UnsafeBufferPointer(start: buffer$, count: Int(Int64(fromJNI: buffer_count, in: environment))))
        }
        """
      ]
    )
  }

  @Test
  func returnUnsafePointer_javaBindings() throws {
    try assertOutput(
      input: returnPointerSource,
      .jni,
      .java,
      expectedChunks: [
        "public static long globalReturnUnsafePointer() {",
        "private static native long $globalReturnUnsafePointer();",
      ]
    )
  }

  @Test
  func returnUnsafePointer_swiftThunks() throws {
    try assertOutput(
      input: returnPointerSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024globalReturnUnsafePointer__")
        public func Java_com_example_swift_SwiftModule__00024globalReturnUnsafePointer__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
          return Int64(Int(bitPattern: SwiftModule.globalReturnUnsafePointer())).getJNILocalRefValue(in: environment)
        }
        """
      ]
    )
  }

  @Test
  func returnUnsafeBufferPointer_javaBindings() throws {
    try assertOutput(
      input: returnBufferPointerSource,
      .jni,
      .java,
      expectedChunks: [
        "public static org.swift.swiftkit.core.SwiftUnsafeBufferPointer globalReturnUnsafeBufferPointer() {",
        "private static native void $globalReturnUnsafeBufferPointer(org.swift.swiftkit.core.SwiftUnsafeBufferPointer resultOut);",
      ]
    )
  }

  @Test
  func returnUnsafeBufferPointer_swiftThunks() throws {
    try assertOutput(
      input: returnBufferPointerSource,
      .jni,
      .swift,
      expectedChunks: [
        """
        do {
          let baseAddressBits$ = Int64(Int(bitPattern: SwiftModule.globalReturnUnsafeBufferPointer().baseAddress))
          environment.interface.SetLongField(environment, resultOut, _JNIMethodIDCache.SwiftUnsafeBufferPointer.baseAddress, baseAddressBits$.getJNIValue(in: environment))
          let countBits$ = Int64(SwiftModule.globalReturnUnsafeBufferPointer().count)
          environment.interface.SetLongField(environment, resultOut, _JNIMethodIDCache.SwiftUnsafeBufferPointer.count, countBits$.getJNIValue(in: environment))
        }
        """
      ]
    )
  }

  @Test
  func takeUnsafeRawBufferPointer_javaBindings() throws {
    try assertOutput(
      input: rawBufferPointerSource,
      .jni,
      .java,
      expectedChunks: [
        "public static void globalTakeUnsafeRawBufferPointer(byte[] buffer) {",
        "private static native void $globalTakeUnsafeRawBufferPointer(byte[] buffer);",
      ]
    )
  }

  @Test
  func takeUnsafeRawBufferPointer_swiftThunks() throws {
    try assertOutput(
      dump: false,
      input: rawBufferPointerSource,
      .jni,
      .swift,
      expectedChunks: [
        "public func Java_com_example_swift_SwiftModule__00024globalTakeUnsafeRawBufferPointer___3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, buffer: jbyteArray?) {"
      ]
    )
  }

  @Test
  func returnUnsafeRawBufferPointer_javaBindings() throws {
    try assertOutput(
      dump: false,
      input: returnRawBufferPointerSource,
      .jni,
      .java,
      expectedChunks: [
        "public static byte[] globalReturnUnsafeRawBufferPointer() {"
      ]
    )
  }

  @Test
  func returnUnsafeRawBufferPointer_swiftThunks() throws {
    try assertOutput(
      dump: false,
      input: returnRawBufferPointerSource,
      .jni,
      .swift,
      expectedChunks: [
        "public func Java_com_example_swift_SwiftModule__00024globalReturnUnsafeRawBufferPointer__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jbyteArray? {",
        "return [UInt8](SwiftModule.globalReturnUnsafeRawBufferPointer()).getJNILocalRefValue(in: environment)",
      ]
    )
  }
}
