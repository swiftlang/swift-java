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
          public static void acceptArray(@Unsigned byte[] array) {
            try(var arena$ = Arena.ofConfined()) {
              swiftjava_SwiftModule_acceptArray_array.call(arena$.allocateFrom(ValueLayout.JAVA_BYTE, array), array.length);
            }
          }
          """,
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
  func func_accept_array_uint8(
    mode: JExtractGenerationMode,
    expectedJavaChunks: [String],
    expectedSwiftChunks: [String]
  ) throws {
    let text =
      """
      public func acceptArray(array: [UInt8])
      """

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )

    try assertOutput(
      input: text,
      mode,
      .swift,
      expectedChunks: expectedSwiftChunks
    )
  }

  @Test(
    "Import: return [UInt8] array",
    arguments: [
      // TODO: implement JNI mode here
      (
        JExtractGenerationMode.ffm,
        /* expected Java chunks */
        [
          """
          /**
           * {snippet lang=c :
           * void (void *, size_t)
           * }
           */
          private static class result$initialize {
            @FunctionalInterface
            public interface Function {
              void apply(java.lang.foreign.MemorySegment _0, long _1);
            }
            public final static class Function$Impl implements Function {
              byte[] result = null;
              public void apply(java.lang.foreign.MemorySegment _0, long _1) {
                this.result = _0.reinterpret(_1).toArray(ValueLayout.JAVA_BYTE);
              }
            }
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
              /* _0: */SwiftValueLayout.SWIFT_POINTER,
              /* _1: */SwiftValueLayout.SWIFT_INT
            );
            private static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);
            private static MemorySegment toUpcallStub(Function fi, Arena arena) {
              return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
            }
          }
          """,
          """
          /**
           * Downcall to Swift:
           * {@snippet lang=swift :
           * public func returnArray() -> [UInt8]
           * }
           */
          @Unsigned
          public static byte[] returnArray() {
            try(var arena$ = Arena.ofConfined()) {
              var result$initialize = new swiftjava_SwiftModule_returnArray.result$initialize.Function$Impl();
              swiftjava_SwiftModule_returnArray.call(swiftjava_SwiftModule_returnArray.result$initialize.toUpcallStub(result$initialize, arena$));
              return result$initialize.result;
            }
          }
          """,
        ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("swiftjava_SwiftModule_returnArray")
          public func swiftjava_SwiftModule_returnArray(_ _result_initialize: @convention(c) (UnsafeRawPointer, Int) -> ()) {
            let _result = returnArray()
            _result.withUnsafeBufferPointer({ (_0) in
              return _result_initialize(_0.baseAddress!, _0.count)
            })
          }
          """
        ]
      )
    ]
  )
  func func_return_array_uint8(
    mode: JExtractGenerationMode,
    expectedJavaChunks: [String],
    expectedSwiftChunks: [String]
  ) throws {
    let text =
      """
      public func returnArray() -> [UInt8]
      """

    var config = Configuration()
    config.logLevel = .trace

    try assertOutput(
      input: text,
      mode,
      .java,
      expectedChunks: expectedJavaChunks
    )

    try assertOutput(
      input: text,
      mode,
      .swift,
      expectedChunks: expectedSwiftChunks
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: JNI mode tests

  @Test("Import: accept [UInt8] array (JNI)")
  func func_accept_array_uint8_jni() throws {
    let text = "public func acceptArray(array: [UInt8])"
    try assertOutput(input: text, .jni, .swift, detectChunkByInitialLines: 2, expectedChunks: [
      """
      @_cdecl("Java_com_example_swift_SwiftModule__00024acceptArray___3B")
      public func Java_com_example_swift_SwiftModule__00024acceptArray___3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, array: jbyteArray?) {
        SwiftModule.acceptArray(array: [UInt8](fromJNI: array, in: environment))
      }
      """
    ])
    try assertOutput(input: text, .jni, .java, detectChunkByInitialLines: 2, expectedChunks: [
      """
      public static void acceptArray(@Unsigned byte[] array) {
        SwiftModule.$acceptArray(Objects.requireNonNull(array, "array must not be null"));
      }
      """,
      "private static native void $acceptArray(byte[] array);",
    ])
  }

  @Test("Import: return [UInt8] array (JNI)")
  func func_return_array_uint8_jni() throws {
    let text = "public func returnArray() -> [UInt8]"
    try assertOutput(input: text, .jni, .swift, detectChunkByInitialLines: 2, expectedChunks: [
      """
      @_cdecl("Java_com_example_swift_SwiftModule__00024returnArray__")
      public func Java_com_example_swift_SwiftModule__00024returnArray__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jbyteArray? {
        return SwiftModule.returnArray().getJNILocalRefValue(in: environment)
      }
      """
    ])
    try assertOutput(input: text, .jni, .java, detectChunkByInitialLines: 2, expectedChunks: [
      """
      @Unsigned
      public static byte[] returnArray() {
        return SwiftModule.$returnArray();
      }
      """,
      "private static native byte[] $returnArray();",
    ])
  }

  @Test("Import: accept UnsafeRawBufferPointer (JNI)")
  func func_accept_unsafeRawBufferPointer_jni() throws {
    let text = "public func receiveBuffer(data: UnsafeRawBufferPointer)"
    try assertOutput(input: text, .jni, .swift, detectChunkByInitialLines: 2, expectedChunks: [
      """
      @_cdecl("Java_com_example_swift_SwiftModule__00024receiveBuffer___3B")
      public func Java_com_example_swift_SwiftModule__00024receiveBuffer___3B(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, data: jbyteArray?) {
        let data$count = Int(environment.interface.GetArrayLength(environment, data))
        let data$ptr = environment.interface.GetByteArrayElements(environment, data, nil)!
        defer { environment.interface.ReleaseByteArrayElements(environment, data, data$ptr, jint(JNI_ABORT)) }
        let data$rbp = UnsafeRawBufferPointer(start: data$ptr, count: data$count)
        SwiftModule.receiveBuffer(data: data$rbp)
      }
      """
    ])
    try assertOutput(input: text, .jni, .java, detectChunkByInitialLines: 2, expectedChunks: [
      """
      public static void receiveBuffer(byte[] data) {
        SwiftModule.$receiveBuffer(data);
      }
      """,
      "private static native void $receiveBuffer(byte[] data);",
    ])
  }
}
