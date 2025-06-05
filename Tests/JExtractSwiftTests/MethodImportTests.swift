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
      st.printJavaBindingWrapperMethod(&printer, funcDecl)
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
            swiftjava___FakeModule_helloWorld.call();
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
      st.printJavaBindingWrapperMethod(&printer, funcDecl)
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
            swiftjava___FakeModule_globalTakeInt_i.call(i);
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
      st.printJavaBindingWrapperMethod(&printer, funcDecl)
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
            try(var arena$ = Arena.ofConfined()) {
                swiftjava___FakeModule_globalTakeIntLongString_i32_l_s.call(i32, l, SwiftKit.toCString(s, arena$));
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
      st.printJavaBindingWrapperMethod(&printer, funcDecl)
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
          MemorySegment _result = swiftArena$.allocate(MySwiftClass.$LAYOUT);
          swiftjava___FakeModule_globalReturnClass.call(_result);
          return new MySwiftClass(_result, swiftArena$);
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
      st.printJavaBindingWrapperMethod(&printer, funcDecl)
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
            swiftjava___FakeModule_MySwiftClass_helloMemberFunction.call(this.$memorySegment());
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
      st.printJavaBindingWrapperMethod(&printer, funcDecl)
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
            $ensureAlive();
            return swiftjava___FakeModule_MySwiftClass_makeInt.call(this.$memorySegment());
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
      st.printJavaBindingWrapperMethod(&printer, initDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public init(len: Swift.Int, cap: Swift.Int)
         * }
         */
        public static MySwiftClass init(long len, long cap, SwiftArena swiftArena$) {
            MemorySegment _result = swiftArena$.allocate(MySwiftClass.$LAYOUT);
            swiftjava___FakeModule_MySwiftClass_init_len_cap.call(len, cap, _result)
            return new MySwiftClass(_result, swiftArena$);
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
      st.printJavaBindingWrapperMethod(&printer, initDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public init(len: Swift.Int, cap: Swift.Int)
         * }
         */
        public static MySwiftStruct init(long len, long cap, SwiftArena swiftArena$) {
            MemorySegment _result = swiftArena$.allocate(MySwiftStruct.$LAYOUT);
            swiftjava___FakeModule_MySwiftStruct_init_len_cap.call(len, cap, _result)
            return new MySwiftStruct(_result, swiftArena$);
        }
        """
    )
  }
}
