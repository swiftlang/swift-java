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
  private static let ifConfigImport = """
  #if canImport(FoundationEssentials)
  import FoundationEssentials
  #else
  import Foundation
  #endif
  """
  private static let foundationData_interfaceFile =
    """
    import Foundation
    
    public func receiveData(dat: Data)
    public func returnData() -> Data
    """

  private static let foundationDataProtocol_interfaceFile =
    """
    import Foundation
    
    public func receiveDataProtocol<T: DataProtocol>(dat: some DataProtocol, dat2: T?)
    """

  private static let essentialsData_interfaceFile =
    """
    import FoundationEssentials
    
    public func receiveData(dat: Data)
    public func returnData() -> Data
    """

  private static let essentialsDataProtocol_interfaceFile =
    """
    import FoundationEssentials
    
    public func receiveDataProtocol<T: DataProtocol>(dat: some DataProtocol, dat2: T?)
    """
  private static let ifConfigData_interfaceFile =
    """
    \(ifConfigImport)
    
    public func receiveData(dat: Data)
    public func returnData() -> Data
    """

  private static let ifConfigDataProtocol_interfaceFile =
    """
    \(ifConfigImport)
    
    public func receiveDataProtocol<T: DataProtocol>(dat: some DataProtocol, dat2: T?)
    """

  @Test("Import Data: Swift thunks", arguments: zip(
    [Self.foundationData_interfaceFile, Self.essentialsData_interfaceFile, Self.ifConfigData_interfaceFile],
    ["import Foundation", "import FoundationEssentials", Self.ifConfigImport]
  ))
  func data_swiftThunk(fileContent: String, expectedImportChunk: String) throws {

    try assertOutput(
      input: fileContent, .ffm, .swift,
      detectChunkByInitialLines: 10,
      expectedChunks: [
        expectedImportChunk,
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
  
  @Test("Import Data: JavaBindings", arguments: [
    Self.foundationData_interfaceFile, Self.essentialsData_interfaceFile, Self.ifConfigData_interfaceFile
  ])
  func data_javaBindings(fileContent: String) throws {
    try assertOutput(
      input: fileContent, .ffm, .java,
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
          return Data.wrapMemoryAddressUnsafe(_result, swiftArena$);
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
          return Data.wrapMemoryAddressUnsafe(_result, swiftArena$);
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

  @Test("Import DataProtocol: Swift thunks", arguments: zip(
    [Self.foundationDataProtocol_interfaceFile, Self.essentialsDataProtocol_interfaceFile, Self.ifConfigDataProtocol_interfaceFile], 
    ["import Foundation", "import FoundationEssentials", Self.ifConfigImport]
  ))
  func dataProtocol_swiftThunk(fileContent: String, expectedImportChunk: String) throws {
    try assertOutput(
      input: fileContent, .ffm, .swift,
      expectedChunks: [
        expectedImportChunk,
        """
        @_cdecl("swiftjava_SwiftModule_receiveDataProtocol_dat_dat2")
        public func swiftjava_SwiftModule_receiveDataProtocol_dat_dat2(_ dat: UnsafeRawPointer, _ dat2: UnsafeRawPointer?) {
          receiveDataProtocol(dat: dat.assumingMemoryBound(to: Data.self).pointee, dat2: dat2?.assumingMemoryBound(to: Data.self).pointee)
        }
        """,

        // Just to make sure 'Data' is imported.
        """
        @_cdecl("swiftjava_getType_SwiftModule_Data")
        """
      ]
    )
  }

  @Test("Import DataProtocol: JavaBindings", arguments: [
    Self.foundationDataProtocol_interfaceFile, Self.essentialsDataProtocol_interfaceFile, Self.ifConfigDataProtocol_interfaceFile
  ])
  func dataProtocol_javaBindings(fileContent: String) throws {

    try assertOutput(
      input: fileContent, .ffm, .java,
      expectedChunks: [
        """
        /**
         * {@snippet lang=c :
         * void swiftjava_SwiftModule_receiveDataProtocol_dat_dat2(const void *dat, const void *dat2)
         * }
         */
        private static class swiftjava_SwiftModule_receiveDataProtocol_dat_dat2 {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* dat: */SwiftValueLayout.SWIFT_POINTER,
            /* dat2: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            SwiftModule.findOrThrow("swiftjava_SwiftModule_receiveDataProtocol_dat_dat2");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment dat, java.lang.foreign.MemorySegment dat2) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(dat, dat2);
              }
              HANDLE.invokeExact(dat, dat2);
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
         * public func receiveDataProtocol<T: DataProtocol>(dat: some DataProtocol, dat2: T?)
         * }
         */
        public static void receiveDataProtocol(Data dat, Optional<Data> dat2) {
          swiftjava_SwiftModule_receiveDataProtocol_dat_dat2.call(dat.$memorySegment(), SwiftRuntime.toOptionalSegmentInstance(dat2));
        }
        """,

        // Just to make sure 'Data' is imported.
        """
        public final class Data extends FFMSwiftInstance implements SwiftValue {
        """
      ]
    )
  }

  // MARK: - JNI Mode Tests

  @Test("Import Data: JNI accept Data")
  func data_jni_accept() throws {
    let text = """
      import Foundation
      public func acceptData(data: Data)
      """

    try assertOutput(
      input: text, .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static void acceptData(Data data) {
          SwiftModule.$acceptData(data.$memoryAddress());
        }
        """
      ])

    try assertOutput(
      input: text, .jni, .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024acceptData__J")
        public func Java_com_example_swift_SwiftModule__00024acceptData__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, data: jlong) {
        """
      ])
  }

  @Test("Import Data: JNI return Data")
  func data_jni_return() throws {
    let text = """
      import Foundation
      public func returnData() -> Data
      """

    try assertOutput(
      input: text, .jni, .java,
      expectedChunks: [
        """
        public static Data returnData(SwiftArena swiftArena$) {
        """
      ])

    try assertOutput(
      input: text, .jni, .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024returnData__")
        public func Java_com_example_swift_SwiftModule__00024returnData__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
        """
      ])
  }

  @Test("Import Data: JNI Data class")
  func data_jni_class() throws {
    let text = """
      import Foundation
      public func f() -> Data
      """

    try assertOutput(
      input: text, .jni, .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        "public final class Data implements JNISwiftInstance, DataProtocol {",
        "public long getCount() {",

        "public static Data fromByteArray(byte[] bytes, SwiftArena swiftArena$) {",

        "public byte[] toByteArray() {",
        "private static native byte[] $toByteArray(long selfPointer);",
        
        "public byte[] toByteArrayIndirectCopy() {",
        "private static native byte[] $toByteArrayIndirectCopy(long selfPointer);"
      ])
  }

}
