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

    // MANGLED NAME: $s14MySwiftLibrary10helloWorldyyF
    public func helloWorld()

    // MANGLED NAME: $s14MySwiftLibrary13globalTakeInt1iySi_tF
    public func globalTakeInt(i: Int)

    // MANGLED NAME: $s14MySwiftLibrary23globalTakeLongIntString1l3i321sys5Int64V_s5Int32VSStF
    public func globalTakeIntLongString(i32: Int32, l: Int64, s: String)

    extension MySwiftClass {
      // MANGLED NAME: $s14MySwiftLibrary0aB5ClassC22helloMemberFunctionInExtension
      public func helloMemberInExtension()
    }

    // MANGLED NAME: $s14MySwiftLibrary0aB5ClassCMa
    public class MySwiftClass {
      // MANGLED NAME: $s14MySwiftLibrary0aB5ClassC3len3capACSi_SitcfC
      public init(len: Swift.Int, cap: Swift.Int)

      // MANGLED NAME: $s14MySwiftLibrary0aB5ClassC19helloMemberFunctionyyF
      public func helloMemberFunction()

      public func makeInt() -> Int

      @objc deinit
    }

    // FIXME: Hack to allow us to translate "String", even though it's not
    // actually available
    // MANGLED NAME: $ss
    public class String {
    }
    """

  @Test("Import: public func helloWorld()")
  func method_helloWorld() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try await st.analyze(swiftInterfacePath: "/fake/Fake.swiftinterface", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first { $0.baseIdentifier == "helloWorld" }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, decl: funcDecl, selfVariant: nil)
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
            var mh$ = helloWorld.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall();
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
  func func_globalTakeInt() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try await st.analyze(swiftInterfacePath: "/fake/__FakeModule/SwiftFile.swiftinterface", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.baseIdentifier == "globalTakeInt"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, decl: funcDecl, selfVariant: nil)
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
            var mh$ = globalTakeInt.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall(i);
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
  func func_globalTakeIntLongString() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try await st.analyze(swiftInterfacePath: "/fake/__FakeModule/SwiftFile.swiftinterface", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.baseIdentifier == "globalTakeIntLongString"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, decl: funcDecl, selfVariant: .memorySegment)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func globalTakeIntLongString(i32: Int32, l: Int64, s: String)
         * }
         */
        public static void globalTakeIntLongString(int i32, long l, com.example.swift.String s) {
            var mh$ = globalTakeIntLongString.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall(i32, l, s.$memorySegment());
                }
                mh$.invokeExact(i32, l, s.$memorySegment());
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test
  func method_class_helloMemberFunction_self_memorySegment() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try await st.analyze(swiftInterfacePath: "/fake/__FakeModule/SwiftFile.swiftinterface", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.baseIdentifier == "helloMemberFunction"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, decl: funcDecl, selfVariant: .memorySegment)
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
        public static void helloMemberFunction(java.lang.foreign.MemorySegment self$) {
            var mh$ = helloMemberFunction.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall(self$);
                }
                mh$.invokeExact(self$);
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test
  func method_class_helloMemberFunction_self_wrapper() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .error

    try await st.analyze(swiftInterfacePath: "/fake/__FakeModule/SwiftFile.swiftinterface", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.baseIdentifier == "helloMemberInExtension"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, decl: funcDecl, selfVariant: .memorySegment)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func helloMemberInExtension()
         * }
         */
        public static void helloMemberInExtension(java.lang.foreign.MemorySegment self$) {
            var mh$ = helloMemberInExtension.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall(self$);
                }
                mh$.invokeExact(self$);
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test
  func test_method_class_helloMemberFunction_self_wrapper() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .info

    try await st.analyze(swiftInterfacePath: "/fake/__FakeModule/SwiftFile.swiftinterface", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.baseIdentifier == "helloMemberFunction"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, decl: funcDecl, selfVariant: .memorySegment)
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
        public static void helloMemberFunction(java.lang.foreign.MemorySegment self$) {
            var mh$ = helloMemberFunction.HANDLE;
            try {
                if (TRACE_DOWNCALLS) {
                    traceDowncall(self$);
                }
                mh$.invokeExact(self$);
            } catch (Throwable ex$) {
                throw new AssertionError("should not reach here", ex$);
            }
        }
        """
    )
  }

  @Test
  func method_class_helloMemberFunction_wrapper() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .info

    try await st.analyze(swiftInterfacePath: "/fake/__FakeModule/SwiftFile.swiftinterface", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.baseIdentifier == "helloMemberFunction"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, decl: funcDecl, selfVariant: .wrapper)
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
            helloMemberFunction($memorySegment());
        }
        """
    )
  }

  @Test
  func method_class_makeInt_wrapper() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .info

    try await st.analyze(swiftInterfacePath: "/fake/__FakeModule/SwiftFile.swiftinterface", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.baseIdentifier == "makeInt"
    }!

    let output = CodePrinter.toString { printer in
      st.printFuncDowncallMethod(&printer, decl: funcDecl, selfVariant: .wrapper)
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
          return (long) makeInt($memorySegment());
        }
        """
    )
  }

  @Test
  func class_constructor() async throws {
    let st = Swift2JavaTranslator(
      javaPackage: "com.example.swift",
      swiftModuleName: "__FakeModule"
    )
    st.log.logLevel = .info

    try await st.analyze(swiftInterfacePath: "/fake/__FakeModule/SwiftFile.swiftinterface", text: class_interfaceFile)

    let initDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.initializers.first {
      $0.identifier == "init(len:cap:)"
    }!

    let output = CodePrinter.toString { printer in
      st.printClassInitializerConstructor(&printer, initDecl, parentName: initDecl.parentName!)
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
        public MySwiftClass(long len, long cap) {
          var mh$ = init_len_cap.HANDLE;
          try {
            if (TRACE_DOWNCALLS) {
              traceDowncall(len, cap);
            }

            this.selfMemorySegment = (MemorySegment) mh$.invokeExact(len, cap, TYPE_METADATA);
          } catch (Throwable ex$) {
            throw new AssertionError(\"should not reach here\", ex$);
          }
        }
        """
    )
  }
}
