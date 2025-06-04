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

import JExtractSwift
import Testing

final class MethodImportTests {
  let class_interfaceFile =
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

    public func globalTakeInt(i: Int)

    public func globalTakeIntLongString(i32: Int32, l: Int64, s: String)
    
    public func globalReturnClass() -> MySwiftClass

    extension MySwiftClass {
      public func helloMemberInExtension()
    }

    public class MySwiftClass {
      public init(len: Swift.Int, cap: Swift.Int)

      public func helloMemberFunction()

      public func makeInt() -> Int

      @objc deinit
    }

    public struct MySwiftStruct {
      public init(len: Swift.Int, cap: Swift.Int) {}
    }
    """

  @Test("Import: public func helloWorld()")
  func method_helloWorld() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try st.analyze(file: "Fake.swift", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first { $0.name == "helloWorld" }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func helloWorld()
         * }
         */
        public static void helloWorld() {
            var mh$ = swiftjava___FakeModule_helloWorld.HANDLE;
            try {
                if (SwiftKit.TRACE_DOWNCALLS) {
                    SwiftKit.traceDowncall();
                }
                
                mh$.invokeExact();
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test("Import: public func globalTakeInt(i: Int)")
  func func_globalTakeInt() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try st.analyze(file: "Fake.swift", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == "globalTakeInt"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift: 
         * {@snippet lang=swift :
         * public func globalTakeInt(i: Int)
         * }
         */
        public static void globalTakeInt(long i) {
            var mh$ = swiftjava___FakeModule_globalTakeInt_i.HANDLE;
            try {
                if (SwiftKit.TRACE_DOWNCALLS) {
                  SwiftKit.traceDowncall(i);
                }
                mh$.invokeExact(i);
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test("Import: public func globalTakeIntLongString(i32: Int32, l: Int64, s: String)")
  func func_globalTakeIntLongString() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try st.analyze(file: "Fake.swift", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == "globalTakeIntLongString"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, funcDecl)
    }

    assertOutput(
      dump: true,
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func globalTakeIntLongString(i32: Int32, l: Int64, s: String)
         * }
         */
        public static void globalTakeIntLongString(int i32, long l, java.lang.String s) {
            var mh$ = swiftjava___FakeModule_globalTakeIntLongString_i32_l_s.HANDLE;
            try(var arena$ = Arena.ofConfined()) {
                var s$ = SwiftKit.toCString(s, arena$);
                if (SwiftKit.TRACE_DOWNCALLS) {
                    SwiftKit.traceDowncall(i32, l, s$);
                }
                mh$.invokeExact(i32, l, s$);
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test("Import: public func globalReturnClass() -> MySwiftClass")
  func func_globalReturnClass() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try st.analyze(file: "Fake.swift", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == "globalReturnClass"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, funcDecl)
    }

    assertOutput(
      dump: true,
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func globalReturnClass() -> MySwiftClass
         * }
         */
        public static MySwiftClass globalReturnClass(SwiftArena swiftArena$) {
          var mh$ = swiftjava___FakeModule_globalReturnClass.HANDLE;
          try {
            MemorySegment _result = swiftArena$.allocate(MySwiftClass.$LAYOUT);
            if (SwiftKit.TRACE_DOWNCALLS) {
                SwiftKit.traceDowncall(_result);
            }
            mh$.invokeExact(_result);
            return new MySwiftClass(_result, swiftArena$);
          } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
          }
        }
        """
    )
  }

  @Test
  func method_class_helloMemberFunction() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try st.analyze(file: "Fake.swift", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.name == "helloMemberFunction"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func helloMemberFunction()
         * }
         */
        public void helloMemberFunction() {
            $ensureAlive()
            var mh$ = swiftjava___FakeModule_MySwiftClass_helloMemberFunction.HANDLE;
            try {
                if (SwiftKit.TRACE_DOWNCALLS) {
                    SwiftKit.traceDowncall(this.$memorySegment());
                }
                mh$.invokeExact(this.$memorySegment());
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test
  func method_class_makeInt() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .info

    try st.analyze(file: "Fake.swift", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.name == "makeInt"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func makeInt() -> Int
         * }
         */
        public long makeInt() {
            $ensureAlive()
            var mh$ = swiftjava___FakeModule_MySwiftClass_makeInt.HANDLE;
            try {
                if (SwiftKit.TRACE_DOWNCALLS) {
                    SwiftKit.traceDowncall(this.$memorySegment());
                }
                return (long) mh$.invokeExact(this.$memorySegment());
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test
  func class_constructor() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .info

    try st.analyze(file: "Fake.swift", text: class_interfaceFile)

    let initDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.initializers.first {
      $0.name == "init"
    }!

    let output = CodePrinter.toString { printer in
      st.printInitializerDowncallConstructor(&printer, initDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Create an instance of {@code MySwiftClass}.
         *
         * {@snippet lang=swift :
         * public init(len: Swift.Int, cap: Swift.Int)
         * }
         */
        public MySwiftClass(long len, long cap, SwiftArena swiftArena$) {
          super(() -> {
            var mh$ = swiftjava___FakeModule_MySwiftClass_init_len_cap.HANDLE;
            try {
              MemorySegment _result = swiftArena$.allocate(MySwiftClass.$LAYOUT);
              if (SwiftKit.TRACE_DOWNCALLS) {
                  SwiftKit.traceDowncall(len, cap, _result);
              }
              mh$.invokeExact(len, cap, _result);
              return _result;
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
          }, swiftArena$);
        }
        """
    )
  }

  @Test
  func struct_constructor() throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .info

    try st.analyze(file: "Fake.swift", text: class_interfaceFile)

    let initDecl: ImportedFunc = st.importedTypes["MySwiftStruct"]!.initializers.first {
      $0.name == "init"
    }!

    let output = CodePrinter.toString { printer in
      st.printInitializerDowncallConstructor(&printer, initDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Create an instance of {@code MySwiftStruct}.
         *
         * {@snippet lang=swift :
         * public init(len: Swift.Int, cap: Swift.Int)
         * }
         */
        public MySwiftStruct(long len, long cap, SwiftArena swiftArena$) {
          super(() -> {
            var mh$ = swiftjava___FakeModule_MySwiftStruct_init_len_cap.HANDLE;
            try {
              MemorySegment _result = swiftArena$.allocate(MySwiftStruct.$LAYOUT);
              if (SwiftKit.TRACE_DOWNCALLS) {
                SwiftKit.traceDowncall(len, cap, _result);
              }
              mh$.invokeExact(len, cap, _result);
              return _result;
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
          }, swiftArena$);
        }
        """
    )
  }
}
