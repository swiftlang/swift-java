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
    let text = 
      """
      public func acceptArray(array: [UInt8])
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
    "Import: return [UInt8] array",
    arguments: [
      // TODO: implement JNI mode here
      (
        JExtractGenerationMode.ffm,
        /* expected Java chunks */
        [
          // """
          // /**
          //  * {snippet lang=c :
          //  * void (*)(void)
          //  * }
          //  */
          // private static class $callback {
          //   @FunctionalInterface
          //   public interface Function {
          //     void apply();
          //   }
          //   private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid();
          //   private static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);
          //   private static MemorySegment toUpcallStub(Function fi, Arena arena) {
          //     return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
          //   }
          // }
          // """,
          // """
          // public static class _result_initialize {
          //   @FunctionalInterface
          //   public interface callback extends swiftjava___FakeModule_callMe_callback.$callback.Function {}
          //   private static MemorySegment $toUpcallStub(callback fi, Arena arena) {
          //     return swiftjava___FakeModule_callMe_callback.$callback.toUpcallStub(fi, arena);
          //   }
          // }
          // """,
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
              _result_initialize callback = (buf, count) -> {

              };
              swiftjava___FakeModule_returnArray.call(_result_initialize.$toUpcallStub(callback, arena$));
              swiftjava_SwiftModule_returnArray.call(_result_pointer, _result_count);
            }
          }
          """
        ],
        // [
        //   """
        //   /**
        //    * Downcall to Swift:
        //    * {@snippet lang=swift :
        //    * public func returnArray() -> [UInt8]
        //    * }
        //    */
        //   @Unsigned
        //   public static byte[] returnArray() {
        //     try(var arena$ = Arena.ofConfined()) {
        //       MemorySegment _result_pointer = arena$.allocate(SwiftValueLayout.SWIFT_POINTER);
        //       MemorySegment _result_count = arena$.allocate(SwiftValueLayout.SWIFT_INT64);
        //       swiftjava_SwiftModule_returnArray.call(_result_pointer, _result_count);
        //       return _result_pointer.get(SwiftValueLayout.SWIFT_POINTER, 0).reinterpret(_result_count.get(SwiftValueLayout.SWIFT_INT64, 0)).toArray(ValueLayout.JAVA_BYTE);
        //     }
        //   }
        //   """
        // ],
        /* expected Swift chunks */
        [
          """
          @_cdecl("swiftjava_SwiftModule_returnArray")
          public func swiftjava_SwiftModule_returnArray(_ _result_initialize: @convention(c) (UnsafeRawPointer, Int) -> ()) {
            let _result = returnArray()
            _result.withUnsafeBufferPointer({ (_0) in
              return _result_initialize(_0.baseAddress, _0.count)
            })
          }
          """
        ]
      )
    ]
  )
  func func_return_array_uint8(mode: JExtractGenerationMode, expectedJavaChunks: [String], expectedSwiftChunks: [String]) throws {
    let text = 
      """
      public func returnArray() -> [UInt8]
      """
    
    var config = Configuration()
    config.logLevel = .trace
    
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