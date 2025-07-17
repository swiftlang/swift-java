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
import Testing

final class DataImportTests {
  let data_interfaceFile =
    """
    import Foundation
    
    public func receiveData(dat: Data)
    public func returnData() -> Data
    """

  let dataProtocol_interfaceFile =
    """
    import Foundation
    
    public func receiveDataProtocol(dat: some DataProtocol)
    """


  @Test("Import Data: Swift thunks")
  func data_swiftThunk() throws {

    try assertOutput(
      input: data_interfaceFile, .ffm, .swift,
      expectedChunks: [
        """
        import Foundation
        """,
        """
        @_cdecl("swiftjava_SwiftModule_receiveData_dat")
        public func swiftjava_SwiftModule_receiveData_dat(_ dat: UnsafeRawPointer) {
          receiveData(dat: dat.assumingMemoryBound(to: Data.self).pointee)
        }
        """,
        """
        @_cdecl("swiftjava_SwiftModule_returnData")
        public func swiftjava_SwiftModule_returnData(_ _result: UnsafeMutableRawPointer) {
          _result.assumingMemoryBound(to: Data.self).initialize(to: returnData())
        }
        """,

        """
        @_cdecl("swiftjava_getType_SwiftModule_Data")
        public func swiftjava_getType_SwiftModule_Data() -> UnsafeMutableRawPointer /* Any.Type */ {
          return unsafeBitCast(Data.self, to: UnsafeMutableRawPointer.self)
        }
        """,

        """
        @_cdecl("swiftjava_SwiftModule_Data_init_bytes_count")
        public func swiftjava_SwiftModule_Data_init_bytes_count(_ bytes: UnsafeRawPointer, _ count: Int, _ _result: UnsafeMutableRawPointer) {
          _result.assumingMemoryBound(to: Data.self).initialize(to: Data(bytes: bytes, count: count))
        }
        """,

        """
        @_cdecl("swiftjava_SwiftModule_Data_count$get")
        public func swiftjava_SwiftModule_Data_count$get(_ self: UnsafeRawPointer) -> Int {
          return self.assumingMemoryBound(to: Data.self).pointee.count
        }
        """,

        """
        @_cdecl("swiftjava_SwiftModule_Data_withUnsafeBytes__")
        public func swiftjava_SwiftModule_Data_withUnsafeBytes__(_ body: @convention(c) (UnsafeRawPointer?, Int) -> Void, _ self: UnsafeRawPointer) {
          self.assumingMemoryBound(to: Data.self).pointee.withUnsafeBytes({ (_0) in
            return body(_0.baseAddress, _0.count)
          })
        }
        """,
      ]
    )
  }

  @Test("Import Data: JavaBindings")
  func data_javaBindings() throws {

    try assertOutput(
      input: data_interfaceFile, .ffm, .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_receiveData_dat(const void *dat)
         * }
         */
        private static class swiftjava_SwiftModule_receiveData_dat {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* dat: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_receiveData_dat");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment dat) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(dat);
              }
              HANDLE.invokeExact(dat);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
        }
        """,

        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func receiveData(dat: Data)
         * }
         */
        public static void receiveData(Data dat) {
          swiftjava_SwiftModule_receiveData_dat.call(dat.$memorySegment());
        }
        """,

        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_returnData(void *_result)
         * }
         */
        private static class swiftjava_SwiftModule_returnData {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* _result: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_returnData");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment _result) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(_result);
              }
              HANDLE.invokeExact(_result);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
        }
        """,

        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func returnData() -> Data
         * }
         */
        public static Data returnData(AllocatingSwiftArena swiftArena$) {
          MemorySegment _result = swiftArena$.allocate(Data.$LAYOUT);
          swiftjava_SwiftModule_returnData.call(_result);
          return new Data(_result, swiftArena$);
        }
        """,


        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_Data_init_bytes_count(const void *bytes, ptrdiff_t count, void *_result)
         * }
         */
        private static class swiftjava_SwiftModule_Data_init_bytes_count {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* bytes: */SwiftValueLayout.SWIFT_POINTER,
            /* count: */SwiftValueLayout.SWIFT_INT,
            /* _result: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_Data_init_bytes_count");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment bytes, long count, java.lang.foreign.MemorySegment _result) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(bytes, count, _result);
              }
              HANDLE.invokeExact(bytes, count, _result);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
        }
        """,

        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public init(bytes: UnsafeRawPointer, count: Int)
         * }
         */
        public static Data init(java.lang.foreign.MemorySegment bytes, long count, AllocatingSwiftArena swiftArena$) {
          MemorySegment _result = swiftArena$.allocate(Data.$LAYOUT);
          swiftjava_SwiftModule_Data_init_bytes_count.call(bytes, count, _result);
          return new Data(_result, swiftArena$);
        }
        """,

        """
        /**
         * {@snippet lang=c :
         * ptrdiff_t swiftjava_SwiftModule_Data_count$get(const void *self)
         * }
         */
        private static class swiftjava_SwiftModule_Data_count$get {
          private static final FunctionDescriptor DESC = FunctionDescriptor.of(
            /* -> */SwiftValueLayout.SWIFT_INT,
            /* self: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_Data_count$get");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static long call(java.lang.foreign.MemorySegment self) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(self);
              }
              return (long) HANDLE.invokeExact(self);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
        } 
        """,

        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public var count: Int
         * }
         */
        public long getCount() {
          $ensureAlive();
          return swiftjava_SwiftModule_Data_count$get.call(this.$memorySegment());
        }
        """,

        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_Data_withUnsafeBytes__(void (*body)(const void *, ptrdiff_t), const void *self)
         * }
         */
        private static class swiftjava_SwiftModule_Data_withUnsafeBytes__ {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* body: */SwiftValueLayout.SWIFT_POINTER,
            /* self: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_Data_withUnsafeBytes__");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment body, java.lang.foreign.MemorySegment self) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(body, self);
              }
              HANDLE.invokeExact(body, self);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
          /**
           * {snippet lang=c :
           * void (*)(const void *, ptrdiff_t)
           * }
           */
          private static class $body {
            @FunctionalInterface
            public interface Function {
              void apply(java.lang.foreign.MemorySegment _0, long _1);
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
        }
        """,

        """
        public static class withUnsafeBytes {
          @FunctionalInterface
          public interface body {
            void apply(java.lang.foreign.MemorySegment _0);
          }
          private static MemorySegment $toUpcallStub(body fi, Arena arena) {
            return swiftjava_SwiftModule_Data_withUnsafeBytes__.$body.toUpcallStub((_0_pointer, _0_count) -> {
              fi.apply(_0_pointer.reinterpret(_0_count));
            }, arena);
          }
        }
        """,


        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func withUnsafeBytes(_ body: (UnsafeRawBufferPointer) -> Void)
         * }
         */
        public void withUnsafeBytes(withUnsafeBytes.body body) {
          $ensureAlive();
          try(var arena$ = Arena.ofConfined()) {
            swiftjava_SwiftModule_Data_withUnsafeBytes__.call(withUnsafeBytes.$toUpcallStub(body, arena$), this.$memorySegment());
          }
        }
        """
      ]
    )
  }

  @Test("Import DataProtocol: Swift thunks")
  func dataProtocol_swiftThunk() throws {
    try assertOutput(
      input: dataProtocol_interfaceFile, .ffm, .swift,
      expectedChunks: [
        """
        import Foundation
        """,
        """
        @_cdecl("swiftjava_SwiftModule_receiveDataProtocol_dat")
        public func swiftjava_SwiftModule_receiveDataProtocol_dat(_ dat: UnsafeRawPointer) {
          receiveDataProtocol(dat: dat.assumingMemoryBound(to: Data.self).pointee)
        }
        """,

        // Just to make sure 'Data' is imported.
        """
        @_cdecl("swiftjava_getType_SwiftModule_Data")
        """
      ]
    )
  }

  @Test("Import DataProtocol: JavaBindings")
  func dataProtocol_javaBindings() throws {

    try assertOutput(
      input: dataProtocol_interfaceFile, .ffm, .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_receiveDataProtocol_dat(const void *dat)
         * }
         */
        private static class swiftjava_SwiftModule_receiveDataProtocol_dat {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* dat: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_receiveDataProtocol_dat");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment dat) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(dat);
              }
              HANDLE.invokeExact(dat);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
        }
        """,

        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func receiveDataProtocol(dat: some DataProtocol)
         * }
         */
        public static void receiveDataProtocol(Data dat) {
          swiftjava_SwiftModule_receiveDataProtocol_dat.call(dat.$memorySegment());
        }
        """,

        // Just to make sure 'Data' is imported.
        """
        public final class Data extends FFMSwiftInstance implements SwiftValue {
        """
      ]
    )
  }
}
