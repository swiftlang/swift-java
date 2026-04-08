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

  @Test(
    "Import Data: Swift thunks",
    arguments: zip(
      [Self.foundationData_interfaceFile, Self.essentialsData_interfaceFile, Self.ifConfigData_interfaceFile],
      ["import Foundation", "import FoundationEssentials", Self.ifConfigImport]
    )
  )
  func data_swiftThunk(fileContent: String, expectedImportChunk: String) throws {

    try assertOutput(
      input: fileContent,
      .ffm,
      .swift,
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
      ]
    )
  }

  @Test(
    "Import Data: JavaBindings",
    arguments: [
      Self.foundationData_interfaceFile, Self.essentialsData_interfaceFile, Self.ifConfigData_interfaceFile,
    ]
  )
  func data_javaBindings(fileContent: String) throws {
    try assertOutput(
      input: fileContent,
      .ffm,
      .java,
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
        public static void receiveData(org.swift.swiftkit.ffm.foundation.Data dat) {
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
        public static org.swift.swiftkit.ffm.foundation.Data returnData(AllocatingSwiftArena swiftArena) {
          MemorySegment result$ = swiftArena.allocate(org.swift.swiftkit.ffm.foundation.Data.$LAYOUT);
          swiftjava_SwiftModule_returnData.call(result$);
          return org.swift.swiftkit.ffm.foundation.Data.wrapMemoryAddressUnsafe(result$, swiftArena);
        }
        """,
      ]
    )
  }

  @Test(
    "Import DataProtocol: Swift thunks",
    arguments: zip(
      [
        Self.foundationDataProtocol_interfaceFile, Self.essentialsDataProtocol_interfaceFile,
        Self.ifConfigDataProtocol_interfaceFile,
      ],
      ["import Foundation", "import FoundationEssentials", Self.ifConfigImport]
    )
  )
  func dataProtocol_swiftThunk(fileContent: String, expectedImportChunk: String) throws {
    try assertOutput(
      input: fileContent,
      .ffm,
      .swift,
      expectedChunks: [
        expectedImportChunk,
        """
        @_cdecl("swiftjava_SwiftModule_receiveDataProtocol_dat_dat2")
        public func swiftjava_SwiftModule_receiveDataProtocol_dat_dat2(_ dat: UnsafeRawPointer, _ dat2: UnsafeRawPointer?) {
          receiveDataProtocol(dat: dat.assumingMemoryBound(to: Data.self).pointee, dat2: dat2?.assumingMemoryBound(to: Data.self).pointee)
        }
        """,
      ]
    )
  }

  @Test(
    "Import DataProtocol: JavaBindings",
    arguments: [
      Self.foundationDataProtocol_interfaceFile, Self.essentialsDataProtocol_interfaceFile,
      Self.ifConfigDataProtocol_interfaceFile,
    ]
  )
  func dataProtocol_javaBindings(fileContent: String) throws {

    try assertOutput(
      input: fileContent,
      .ffm,
      .java,
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
        public static void receiveDataProtocol(org.swift.swiftkit.ffm.foundation.Data dat, java.util.Optional<org.swift.swiftkit.ffm.foundation.Data> dat2) {
          swiftjava_SwiftModule_receiveDataProtocol_dat_dat2.call(dat.$memorySegment(), SwiftRuntime.toOptionalSegmentInstance(dat2));
        }
        """,
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
      input: text,
      .jni,
      .java,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public static void acceptData(org.swift.swiftkit.core.foundation.Data data) {
          SwiftModule.$acceptData(data.$memoryAddress());
        }
        """
      ]
    )

    try assertOutput(
      input: text,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024acceptData__J")
        public func Java_com_example_swift_SwiftModule__00024acceptData__J(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, data: jlong) {
        """
      ]
    )
  }

  @Test("Import Data: JNI return Data")
  func data_jni_return() throws {
    let text = """
      import Foundation
      public func returnData() -> Data
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      expectedChunks: [
        """
        public static org.swift.swiftkit.core.foundation.Data returnData(SwiftArena swiftArena) {
        """
      ]
    )

    try assertOutput(
      input: text,
      .jni,
      .swift,
      expectedChunks: [
        """
        @_cdecl("Java_com_example_swift_SwiftModule__00024returnData__")
        public func Java_com_example_swift_SwiftModule__00024returnData__(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass) -> jlong {
        """
      ]
    )
  }

  // ==== -----------------------------------------------------------------------
  // MARK: JNI DataProtocol generic parameter

  @Test("Import DataProtocol: JNI generic parameter")
  func dataProtocol_jni_genericParameter() throws {
    let text = """
      import Foundation

      public struct MyResult {
        public init() {}
      }
      public func processData<D: DataProtocol>(data: D) -> MyResult
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static <D extends org.swift.swiftkit.core.foundation.DataProtocol> MyResult processData(D data, SwiftArena swiftArena) {
        """
      ]
    )
  }

  @Test("Import DataProtocol: JNI multiple generic parameters")
  func dataProtocol_jni_multipleGenericParameters() throws {
    let text = """
      import Foundation

      public func verify<D1: DataProtocol, D2: DataProtocol>(first: D1, second: D2) -> Bool
      """

    try assertOutput(
      input: text,
      .jni,
      .java,
      detectChunkByInitialLines: 2,
      expectedChunks: [
        """
        public static <D1 extends org.swift.swiftkit.core.foundation.DataProtocol, D2 extends org.swift.swiftkit.core.foundation.DataProtocol> boolean verify(D1 first, D2 second) {
        """
      ]
    )
  }

  @Test("Import DataProtocol: JNI generic parameter Swift thunk")
  func dataProtocol_jni_genericParameter_swiftThunk() throws {
    let text = """
      import Foundation

      public struct MyResult {
        public init() {}
      }
      public func processData<D: DataProtocol>(data: D) -> MyResult
      """

    try assertOutput(
      input: text,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public func Java_com_example_swift_SwiftModule__00024processData__Ljava_lang_Object_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, data: jobject?) -> jlong {
        """,
        """
          result$.initialize(to: SwiftModule.processData(data: dataswiftObject$))
        """,
      ]
    )
  }

  @Test("Import DataProtocol: JNI mixed generic and some Swift thunk")
  func dataProtocol_jni_multipleGenericParameters_swiftThunk() throws {
    let text = """
      import Foundation

      public func verify<D1: DataProtocol>(first: D1, second: some DataProtocol) -> Bool
      """

    try assertOutput(
      input: text,
      .jni,
      .swift,
      detectChunkByInitialLines: 1,
      expectedChunks: [
        """
        public func Java_com_example_swift_SwiftModule__00024verify__Ljava_lang_Object_2Ljava_lang_Object_2(environment: UnsafeMutablePointer<JNIEnv?>!, thisClass: jclass, first: jobject?, second: jobject?) -> jboolean {
        """,
        """
          return SwiftModule.verify(first: firstswiftObject$, second: secondswiftObject$).getJNILocalRefValue(in: environment)
        """,
      ]
    )
  }

}
