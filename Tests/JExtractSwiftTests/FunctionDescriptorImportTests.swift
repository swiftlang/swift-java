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

@Suite
final class FunctionDescriptorTests {
  let interfaceFile =
    """
    // swift-interface-format-version: 1.0
    // swift-compiler-version: Apple Swift version 6.0 effective-5.10 (swiftlang-6.0.0.7.6 clang-1600.0.24.1)
    // swift-module-flags: -target arm64-apple-macosx15.0 -enable-objc-interop -enable-library-evolution -module-name MySwiftLibrary
    import Darwin.C
    import Darwin
    import Swift
    import _Concurrency
    import _StringProcessing
    import _SwiftConcurrencyShims

    public func helloWorld()
    public func globalTakeInt(i: Swift.Int)

    public func globalTakeLongInt(l: Int64, i32: Int32)

    public func echoInt(i: Int) -> Int

    public class MySwiftClass {
      public init(len: Swift.Int, cap: Swift.Int)
      @objc deinit

      public var counter: Int32
    }
    """

  @Test
  func FunctionDescriptor_globalTakeInt() throws {
    try functionDescriptorTest("globalTakeInt") { output in
      assertOutput(
        output,
        expected:
          """
          /**
           * {@snippet lang=c :
           * void swiftjava_SwiftModule_globalTakeInt_i(ptrdiff_t i)
           * }
           */
          private static class swiftjava_SwiftModule_globalTakeInt_i {
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
              /* i: */SwiftValueLayout.SWIFT_INT
            );
            private static final MemorySegment ADDR =
              SwiftModule.findOrThrow("swiftjava_SwiftModule_globalTakeInt_i");
            private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
            public static void call(long i) {
              try {
                if (CallTraces.TRACE_DOWNCALLS) {
                  CallTraces.traceDowncall(i);
                }
                HANDLE.invokeExact(i);
              } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
              }
            }
          }
          """
      )
    }
  }

  @Test
  func FunctionDescriptor_globalTakeLongIntString() throws {
    try functionDescriptorTest("globalTakeLongInt") { output in
      assertOutput(
        output,
        expected:
          """
          /**
           * {@snippet lang=c :
           * void swiftjava_SwiftModule_globalTakeLongInt_l_i32(int64_t l, int32_t i32)
           * }
           */
          private static class swiftjava_SwiftModule_globalTakeLongInt_l_i32 {
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
              /* l: */SwiftValueLayout.SWIFT_INT64,
              /* i32: */SwiftValueLayout.SWIFT_INT32
            );
            private static final MemorySegment ADDR =
              SwiftModule.findOrThrow("swiftjava_SwiftModule_globalTakeLongInt_l_i32");
            private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
            public static void call(long l, int i32) {
              try {
                if (CallTraces.TRACE_DOWNCALLS) {
                  CallTraces.traceDowncall(l, i32);
                }
                HANDLE.invokeExact(l, i32);
              } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
              }
            }
          }
          """
      )
    }
  }

  @Test
  func FunctionDescriptor_echoInt() throws {
    try functionDescriptorTest("echoInt") { output in
      assertOutput(
        output,
        expected:
          """
          /**
           * {@snippet lang=c :
           * ptrdiff_t swiftjava_SwiftModule_echoInt_i(ptrdiff_t i)
           * }
           */
          private static class swiftjava_SwiftModule_echoInt_i {
            private static final FunctionDescriptor DESC = FunctionDescriptor.of(
              /* -> */SwiftValueLayout.SWIFT_INT,
              /* i: */SwiftValueLayout.SWIFT_INT
            );
            private static final MemorySegment ADDR =
              SwiftModule.findOrThrow("swiftjava_SwiftModule_echoInt_i");
            private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
            public static long call(long i) {
              try {
                if (CallTraces.TRACE_DOWNCALLS) {
                  CallTraces.traceDowncall(i);
                }
                return (long) HANDLE.invokeExact(i);
              } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
              }
            }
          }
          """
      )
    }
  }

  @Test
  func FunctionDescriptor_class_counter_get() throws {
    try variableAccessorDescriptorTest("counter", .getter) { output in
      assertOutput(
        output,
        expected:
          """
          /**
           * {@snippet lang=c :
           * int32_t swiftjava_SwiftModule_MySwiftClass_counter$get(const void *self)
           * }
           */
          private static class swiftjava_SwiftModule_MySwiftClass_counter$get {
            private static final FunctionDescriptor DESC = FunctionDescriptor.of(
              /* -> */SwiftValueLayout.SWIFT_INT32,
              /* self: */SwiftValueLayout.SWIFT_POINTER
            );
            private static final MemorySegment ADDR =
              SwiftModule.findOrThrow("swiftjava_SwiftModule_MySwiftClass_counter$get");
            private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
            public static int call(java.lang.foreign.MemorySegment self) {
              try {
                if (CallTraces.TRACE_DOWNCALLS) {
                  CallTraces.traceDowncall(self);
                }
                return (int) HANDLE.invokeExact(self);
              } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
              }
            }
          }
          """
      )
    }
  }
  @Test
  func FunctionDescriptor_class_counter_set() throws {
    try variableAccessorDescriptorTest("counter", .setter) { output in
      assertOutput(
        output,
        expected:
          """
          /**
           * {@snippet lang=c :
           * void swiftjava_SwiftModule_MySwiftClass_counter$set(int32_t newValue, const void *self)
           * }
           */
          private static class swiftjava_SwiftModule_MySwiftClass_counter$set {
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
              /* newValue: */SwiftValueLayout.SWIFT_INT32,
              /* self: */SwiftValueLayout.SWIFT_POINTER
            );
            private static final MemorySegment ADDR =
              SwiftModule.findOrThrow("swiftjava_SwiftModule_MySwiftClass_counter$set");
            private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
            public static void call(int newValue, java.lang.foreign.MemorySegment self) {
              try {
                if (CallTraces.TRACE_DOWNCALLS) {
                  CallTraces.traceDowncall(newValue, self);
                }
                HANDLE.invokeExact(newValue, self);
              } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
              }
            }
          }
          """
      )
    }
  }

}

extension FunctionDescriptorTests {

  func functionDescriptorTest(
    _ methodIdentifier: String,
    javaPackage: String = "com.example.swift",
    swiftModuleName: String = "SwiftModule",
    logLevel: Logger.Level = .trace,
    body: (String) throws -> Void
  ) throws {
    var config = Configuration()
    config.swiftModule = swiftModuleName
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = logLevel

    try st.analyze(file: "/fake/Sample.swiftinterface", text: interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == methodIdentifier
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: javaPackage,
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingDescriptorClass(&printer, funcDecl)
    }

    try body(output)
  }

  func variableAccessorDescriptorTest(
    _ identifier: String,
    _ accessorKind: SwiftAPIKind,
    javaPackage: String = "com.example.swift",
    swiftModuleName: String = "SwiftModule",
    logLevel: Logger.Level = .trace,
    body: (String) throws -> Void
  ) throws {
    var config = Configuration()
    config.swiftModule = swiftModuleName
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = logLevel

    try st.analyze(file: "/fake/Sample.swiftinterface", text: interfaceFile)

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: javaPackage,
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let accessorDecl: ImportedFunc? =
      st.importedTypes.values.compactMap {
        $0.variables.first {
          $0.name == identifier && $0.apiKind == accessorKind
        }
      }.first
    guard let accessorDecl else {
      fatalError("Cannot find descriptor of: \(identifier)")
    }

    let getOutput = CodePrinter.toString { printer in
      generator.printJavaBindingDescriptorClass(&printer, accessorDecl)
    }

    try body(getOutput)
  }
}
