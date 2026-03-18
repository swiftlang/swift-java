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

import CodePrinting
import JExtractSwiftLib
import SwiftJavaConfigurationShared
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

    /// Hello World!
    public func /*comment*/helloWorld()

    public func globalTakeInt(i: Int)

    public func globalTakeIntLongString(
      i32: Int32,
      l: Int64,
      s: String
    )

    public func globalReturnClass() -> MySwiftClass

    public func globalReturnAny() -> Any

    public func swapRawBufferPointer(buffer: UnsafeRawBufferPointer) -> UnsafeMutableRawBufferPointer

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
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let funcDecl = st.importedGlobalFuncs.first { $0.name == "helloWorld" }!

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Hello World!
         * 
         * <p>Downcall to Swift:
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
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == "globalTakeInt"
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, funcDecl)
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
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == "globalTakeIntLongString"
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, funcDecl)
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
        public static void globalTakeIntLongString(int i32, long l, java.lang.String s) {
            try(var arena$ = Arena.ofConfined()) {
                swiftjava___FakeModule_globalTakeIntLongString_i32_l_s.call(i32, l, SwiftRuntime.toCString(s, arena$));
            }
        }
        """
    )
  }

  @Test("Import: public func globalReturnClass() -> MySwiftClass")
  func func_globalReturnClass() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == "globalReturnClass"
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func globalReturnClass() -> MySwiftClass
         * }
         */
        public static MySwiftClass globalReturnClass(AllocatingSwiftArena swiftArena) {
          MemorySegment _result = swiftArena.allocate(MySwiftClass.$LAYOUT);
          swiftjava___FakeModule_globalReturnClass.call(_result);
          return MySwiftClass.wrapMemoryAddressUnsafe(_result, swiftArena);
        }
        """
    )
  }

  @Test("Import: func swapRawBufferPointer(buffer: _)")
  func func_globalSwapRawBufferPointer() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let funcDecl = st.importedGlobalFuncs.first {
      $0.name == "swapRawBufferPointer"
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, funcDecl)
    }

    assertOutput(
      output,
      expected:
        """
        /**
         * Downcall to Swift:
         * {@snippet lang=swift :
         * public func swapRawBufferPointer(buffer: UnsafeRawBufferPointer) -> UnsafeMutableRawBufferPointer
         * }
         */
        public static java.lang.foreign.MemorySegment swapRawBufferPointer(java.lang.foreign.MemorySegment buffer) {
          try(var arena$ = Arena.ofConfined()) {
            MemorySegment _result_pointer = arena$.allocate(SwiftValueLayout.SWIFT_POINTER);
            MemorySegment _result_count = arena$.allocate(SwiftValueLayout.SWIFT_INT64);
            swiftjava___FakeModule_swapRawBufferPointer_buffer.call(buffer, buffer.byteSize(), _result_pointer, _result_count);
            return _result_pointer.get(SwiftValueLayout.SWIFT_POINTER, 0).reinterpret(_result_count.get(SwiftValueLayout.SWIFT_INT64, 0));
          }
        }
        """
    )
  }

  @Test
  func method_class_helloMemberFunction() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.name == "helloMemberFunction"
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, funcDecl)
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
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .info

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let funcDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.methods.first {
      $0.name == "makeInt"
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, funcDecl)
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
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .info

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let initDecl: ImportedFunc = st.importedTypes["MySwiftClass"]!.initializers.first {
      $0.name == "init"
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, initDecl)
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
        public static MySwiftClass init(long len, long cap, AllocatingSwiftArena swiftArena) {
            MemorySegment _result = swiftArena.allocate(MySwiftClass.$LAYOUT);
            swiftjava___FakeModule_MySwiftClass_init_len_cap.call(len, cap, _result)
            return MySwiftClass.wrapMemoryAddressUnsafe(_result, swiftArena);
        }
        """
    )
  }

  @Test
  func struct_constructor() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)

    st.log.logLevel = .info

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    let initDecl: ImportedFunc = st.importedTypes["MySwiftStruct"]!.initializers.first {
      $0.name == "init"
    }!

    let generator = FFMSwift2JavaGenerator(
      config: config,
      translator: st,
      javaPackage: "com.example.swift",
      swiftOutputDirectory: "/fake",
      javaOutputDirectory: "/fake"
    )

    let output = CodePrinter.toString { printer in
      generator.printJavaBindingWrapperMethod(&printer, initDecl)
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
        public static MySwiftStruct init(long len, long cap, AllocatingSwiftArena swiftArena) {
            MemorySegment _result = swiftArena.allocate(MySwiftStruct.$LAYOUT);
            swiftjava___FakeModule_MySwiftStruct_init_len_cap.call(len, cap, _result)
            return MySwiftStruct.wrapMemoryAddressUnsafe(_result, swiftArena);
        }
        """
    )
  }

  @Test("Import: public func globalReturnAny() -> Any")
  func func_globalReturnAny() throws {
    var config = Configuration()
    config.swiftModule = "__FakeModule"
    let st = Swift2JavaTranslator(config: config)
    st.log.logLevel = .error

    try st.analyze(path: "Fake.swift", text: class_interfaceFile)

    #expect(
      !st.importedGlobalFuncs.contains {
        $0.name == "globalReturnAny"
      },
      "'Any' return type is not supported yet"
    )
  }

  // ==== -------------------------------------------------------------------
  // MARK: FFM overloaded method disambiguation

  let overloaded_interfaceFile =
    """
    import Swift

    public func takeValue(a: Swift.String) -> Swift.Int
    public func takeValue(b: Swift.String) -> Swift.Int
    public func uniqueFunc(x: Swift.Int) -> Swift.Int
    public func overloaded(a: Swift.Int) -> Swift.Int
    public func overloaded(a: Swift.String) -> Swift.Int

    public class OverloadedClass {
      public func bar(a: Swift.String)
      public func bar(b: Swift.String)
      public func unique(x: Swift.Int)
    }
    """

  @Test("FFM: Overloaded global functions get suffixed Java names")
  func ffm_overloaded_global_functions_suffixed() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .ffm,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public static long takeValueA(java.lang.String a)",
        "public static long takeValueB(java.lang.String b)",
      ]
    )
  }

  @Test("FFM: Non-overloaded functions keep clean names")
  func ffm_non_overloaded_functions_clean_names() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .ffm,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public static long uniqueFunc(long x)"
      ],
      notExpectedChunks: [
        "public static long uniqueFunc_x("
      ]
    )
  }

  @Test("FFM: Same name but different types — no suffix needed")
  func ffm_overloaded_different_types_no_suffix() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .ffm,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public static long overloaded(long a)",
        "public static long overloaded(java.lang.String a)",
      ],
      notExpectedChunks: [
        "public static long overloaded_a("
      ]
    )
  }

  @Test("FFM: Overloaded methods on a type get suffixed Java names")
  func ffm_overloaded_methods_on_type_suffixed() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .ffm,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public void barA(java.lang.String a)",
        "public void barB(java.lang.String b)",
      ]
    )
  }

  @Test("FFM: Non-overloaded method on a type keeps clean name")
  func ffm_non_overloaded_method_on_type_clean_name() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .ffm,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public void unique(long x)"
      ],
      notExpectedChunks: [
        "public void unique_x("
      ]
    )
  }

  let propertyMethodConflict_interfaceFile =
    """
    import Swift

    public class MyClass {
      public var name: Swift.Int { get }
      public func getName() -> Swift.Int
    }
    """

  @Test("FFM: Property getter and method with same Java name are disambiguated")
  func ffm_property_getter_vs_method_conflict() throws {
    try assertOutput(
      input: propertyMethodConflict_interfaceFile,
      .ffm,
      .java,
      swiftModuleName: "ConflictModule",
      expectedChunks: [
        // Property getter keeps standard Java bean name
        "public long getName()",
        // Method gets a trailing underscore to avoid the conflict
        "public long getName_()",
      ]
    )
  }

  let argumentLabel_interfaceFile =
    """
    import Swift

    public func takeValue(outer name: Swift.String) -> Swift.Int
    public func takeValue(another name: Swift.String) -> Swift.Int
    """

  @Test("FFM: Overloaded functions with argument labels use label for suffix")
  func ffm_overloaded_argument_labels() throws {
    try assertOutput(
      input: argumentLabel_interfaceFile,
      .ffm,
      .java,
      swiftModuleName: "LabelModule",
      expectedChunks: [
        "public static long takeValueOuter(java.lang.String name)",
        "public static long takeValueAnother(java.lang.String name)",
      ]
    )
  }

  // ==== -------------------------------------------------------------------
  // MARK: JNI overloaded method disambiguation

  @Test("JNI: Overloaded global functions get suffixed Java names")
  func jni_overloaded_global_functions_suffixed() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .jni,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public static long takeValueA(java.lang.String a)",
        "public static long takeValueB(java.lang.String b)",
      ]
    )
  }

  @Test("JNI: Non-overloaded functions keep clean names")
  func jni_non_overloaded_functions_clean_names() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .jni,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public static long uniqueFunc(long x)"
      ],
      notExpectedChunks: [
        "public static long uniqueFunc_x("
      ]
    )
  }

  @Test("JNI: Same name but different types — no suffix needed")
  func jni_overloaded_different_types_no_suffix() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .jni,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public static long overloaded(long a)",
        "public static long overloaded(java.lang.String a)",
      ],
      notExpectedChunks: [
        "public static long overloaded_a("
      ]
    )
  }

  @Test("JNI: Overloaded methods on a type get suffixed Java names")
  func jni_overloaded_methods_on_type_suffixed() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .jni,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public void barA(java.lang.String a)",
        "public void barB(java.lang.String b)",
      ]
    )
  }

  @Test("JNI: Non-overloaded method on a type keeps clean name")
  func jni_non_overloaded_method_on_type_clean_name() throws {
    try assertOutput(
      input: overloaded_interfaceFile,
      .jni,
      .java,
      swiftModuleName: "OverloadModule",
      expectedChunks: [
        "public void unique(long x)"
      ],
      notExpectedChunks: [
        "public void unique_x("
      ]
    )
  }

  @Test("JNI: Property getter and method with same Java name are disambiguated")
  func jni_property_getter_vs_method_conflict() throws {
    try assertOutput(
      input: propertyMethodConflict_interfaceFile,
      .jni,
      .java,
      swiftModuleName: "ConflictModule",
      expectedChunks: [
        "public long getName()",
        "public long getName_()",
      ]
    )
  }

  @Test("JNI: Overloaded functions with argument labels use label for suffix")
  func jni_overloaded_argument_labels() throws {
    try assertOutput(
      input: argumentLabel_interfaceFile,
      .jni,
      .java,
      swiftModuleName: "LabelModule",
      expectedChunks: [
        "public static long takeValueOuter(java.lang.String name)",
        "public static long takeValueAnother(java.lang.String name)",
      ]
    )
  }
}
