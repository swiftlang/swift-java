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

final class FuncCallbackImportTests {

  static let class_interfaceFile =
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

    public func callMe(callback: () -> Void)
    public func callMeMore(callback: (UnsafeRawPointer, Float) -> Int, fn: () -> ())
    public func withBuffer(body: (UnsafeRawBufferPointer) -> Int)
    """

  @Test("Import: public func callMe(callback: () -> Void)")
  func func_callMeFunc_callback() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(file: "Fake.swift", text: Self.class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first { $0.name == "callMe" }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printFunctionDowncallMethods(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        // ==== --------------------------------------------------
        // callMe
        /**
         * {@snippet lang=c :
         * void swiftjava___FakeModule_callMe_callback(void (*callback)(void))
         * }
         */
        private static class swiftjava___FakeModule_callMe_callback {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* callback: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            __FakeModule.findOrThrow("swiftjava___FakeModule_callMe_callback");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment callback) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(callback);
              }
              HANDLE.invokeExact(callback);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
          /**
           * {snippet lang=c :
           * void (*)(void)
           * }
           */
          private static class $callback {
            @FunctionalInterface
            public interface Function {
              void apply();
            }
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid();
            private static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);
            private static MemorySegment toUpcallStub(Function fi, Arena arena) {
              return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
            }
          }
        }
        public static class callMe {
          @FunctionalInterface
          public interface callback extends swiftjava___FakeModule_callMe_callback.$callback.Function {}
          private static MemorySegment $toUpcallStub(callback fi, Arena arena) {
            return swiftjava___FakeModule_callMe_callback.$callback.toUpcallStub(fi, arena);
          }
        }
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func callMe(callback: () -> Void)
         * }
         */
        public static void callMe(callMe.callback callback) {
          try(var arena$ = Arena.ofConfined()) {
            swiftjava___FakeModule_callMe_callback.call(callMe.$toUpcallStub(callback, arena$));
          }
        }
        """
    )
  }

  @Test("Import: public func callMeMore(callback: (UnsafeRawPointer, Float) -> Int, fn: () -> ())")
  func func_callMeMoreFunc_callback() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)

    try st.analyze(file: "Fake.swift", text: Self.class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first { $0.name == "callMeMore" }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printFunctionDowncallMethods(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        // ==== --------------------------------------------------
        // callMeMore
        /**
         * {@snippet lang=c :
         * void swiftjava___FakeModule_callMeMore_callback_fn(ptrdiff_t (*callback)(const void *, float), void (*fn)(void))
         * }
         */
        private static class swiftjava___FakeModule_callMeMore_callback_fn {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* callback: */SwiftValueLayout.SWIFT_POINTER,
            /* fn: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            __FakeModule.findOrThrow("swiftjava___FakeModule_callMeMore_callback_fn");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment callback, java.lang.foreign.MemorySegment fn) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(callback, fn);
              }
              HANDLE.invokeExact(callback, fn);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
          /**
           * {snippet lang=c :
           * ptrdiff_t (*)(const void *, float)
           * }
           */
          private static class $callback {
            @FunctionalInterface
            public interface Function {
              long apply(java.lang.foreign.MemorySegment _0, float _1);
            }
            private static final FunctionDescriptor DESC = FunctionDescriptor.of(
              /* -> */SwiftValueLayout.SWIFT_INT,
              /* _0: */SwiftValueLayout.SWIFT_POINTER,
              /* _1: */SwiftValueLayout.SWIFT_FLOAT
            );
            private static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);
            private static MemorySegment toUpcallStub(Function fi, Arena arena) {
              return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
            }
          }
          /**
           * {snippet lang=c :
           * void (*)(void)
           * }
           */
          private static class $fn {
            @FunctionalInterface
            public interface Function {
              void apply();
            }
            private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid();
            private static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);
            private static MemorySegment toUpcallStub(Function fi, Arena arena) {
              return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
            }
          }
        }
        public static class callMeMore {
          @FunctionalInterface
          public interface callback extends swiftjava___FakeModule_callMeMore_callback_fn.$callback.Function {}
          private static MemorySegment $toUpcallStub(callback fi, Arena arena) {
            return swiftjava___FakeModule_callMeMore_callback_fn.$callback.toUpcallStub(fi, arena);
          }
          @FunctionalInterface
          public interface fn extends swiftjava___FakeModule_callMeMore_callback_fn.$fn.Function {}
          private static MemorySegment $toUpcallStub(fn fi, Arena arena) {
            return swiftjava___FakeModule_callMeMore_callback_fn.$fn.toUpcallStub(fi, arena);
          }
        }
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func callMeMore(callback: (UnsafeRawPointer, Float) -> Int, fn: () -> ())
         * }
         */
        public static void callMeMore(callMeMore.callback callback, callMeMore.fn fn) {
          try(var arena$ = Arena.ofConfined()) {
            swiftjava___FakeModule_callMeMore_callback_fn.call(callMeMore.$toUpcallStub(callback, arena$), callMeMore.$toUpcallStub(fn, arena$));
          }
        }
        """
    )
  }

  @Test("Import: public func withBuffer(body: (UnsafeRawBufferPointer) -> Int)")
  func func_withBuffer_body() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(file: "Fake.swift", text: Self.class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first { $0.name == "withBuffer" }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printFunctionDowncallMethods(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        // ==== --------------------------------------------------
        // withBuffer
        /**
         * {@snippet lang=c :
         * void swiftjava___FakeModule_withBuffer_body(ptrdiff_t (*body)(const void *, ptrdiff_t))
         * }
         */
        private static class swiftjava___FakeModule_withBuffer_body {
          private static final FunctionDescriptor DESC = FunctionDescriptor.ofVoid(
            /* body: */SwiftValueLayout.SWIFT_POINTER
          );
          private static final MemorySegment ADDR =
            __FakeModule.findOrThrow("swiftjava___FakeModule_withBuffer_body");
          private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
          public static void call(java.lang.foreign.MemorySegment body) {
            try {
              if (CallTraces.TRACE_DOWNCALLS) {
                CallTraces.traceDowncall(body);
              }
              HANDLE.invokeExact(body);
            } catch (Throwable ex$) {
              throw new AssertionError("should not reach here", ex$);
            }
          }
          /**
           * {snippet lang=c :
           * ptrdiff_t (*)(const void *, ptrdiff_t)
           * }
           */
          private static class $body {
            @FunctionalInterface
            public interface Function {
              long apply(java.lang.foreign.MemorySegment _0, long _1);
            }
            private static final FunctionDescriptor DESC = FunctionDescriptor.of(
              /* -> */SwiftValueLayout.SWIFT_INT,
              /* _0: */SwiftValueLayout.SWIFT_POINTER,
              /* _1: */SwiftValueLayout.SWIFT_INT
            );
            private static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);
            private static MemorySegment toUpcallStub(Function fi, Arena arena) {
              return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
            }
          }
        }
        public static class withBuffer {
          @FunctionalInterface
          public interface body {
            long apply(java.lang.foreign.MemorySegment _0);
          }
          private static MemorySegment $toUpcallStub(body fi, Arena arena) {
            return swiftjava___FakeModule_withBuffer_body.$body.toUpcallStub((_0_pointer, _0_count) -> {
              return fi.apply(_0_pointer.reinterpret(_0_count));
            }, arena);
          }
        }
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func withBuffer(body: (UnsafeRawBufferPointer) -> Int)
         * }
         */
        public static void withBuffer(withBuffer.body body) {
          try(var arena$ = Arena.ofConfined()) {
            swiftjava___FakeModule_withBuffer_body.call(withBuffer.$toUpcallStub(body, arena$));
          }
        }
        """
    )
  }
}
