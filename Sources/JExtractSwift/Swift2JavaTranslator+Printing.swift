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

import Foundation
import SwiftBasicFormat
import SwiftParser
import SwiftSyntax

// ==== ---------------------------------------------------------------------------------------------------------------
// MARK: File writing

let PATH_SEPARATOR = "/"  // TODO: Windows

extension Swift2JavaTranslator {

  /// Every imported public type becomes a public class in its own file in Java.
  public func writeExportedJavaSources(outputDirectory: String) throws {
    var printer = CodePrinter()
    try writeExportedJavaSources(outputDirectory: outputDirectory, printer: &printer)
  }

  public func writeExportedJavaSources(outputDirectory: String, printer: inout CodePrinter) throws {
    for (_, ty) in importedTypes.sorted(by: { (lhs, rhs) in lhs.key < rhs.key }) {
      let filename = "\(ty.javaClassName).java"
      log.info("Printing contents: \(filename)")
      printImportedClass(&printer, ty)

      if let outputFile = try printer.writeContents(
        outputDirectory: outputDirectory,
        javaPackagePath: javaPackagePath,
        filename: filename
      ) {
        print("[swift-java] Generated: \(ty.javaClassName.bold).java (at \(outputFile))")
      }
    }
  }

  public func writeSwiftThunkSources(outputDirectory: String) throws {
    var printer = CodePrinter()

    try writeSwiftThunkSources(outputDirectory: outputDirectory, printer: &printer)
  }

  public func writeSwiftThunkSources(outputDirectory: String, printer: inout CodePrinter) throws {
    // ==== Globals
    for decl in self.importedGlobalFuncs {
      printSwiftThunkSources(&printer, decl: decl)
    }

    let moduleFilenameBase = "\(self.swiftModuleName)Module+SwiftJava"
    let moduleFilename = "\(moduleFilenameBase).swift"
    log.info("Printing contents: \(moduleFilename)")
    do {
      if let outputFile = try printer.writeContents(
        outputDirectory: outputDirectory,
        javaPackagePath: nil,
        filename: moduleFilename) {
        print("[swift-java] Generated: \(moduleFilenameBase.bold).java (at \(outputFile)")
      }
    } catch {
      log.warning("Failed to write to Swift thunks: \(moduleFilename)")
    }

    // === All types
    for (_, ty) in importedTypes.sorted(by: { (lhs, rhs) in lhs.key < rhs.key }) {
      let fileNameBase = "\(ty.swiftTypeName)+SwiftJava"
      let filename = "\(fileNameBase).swift"
      log.info("Printing contents: \(filename)")

      do {
        try printSwiftThunkSources(&printer, ty: ty)

        if let outputFile = try printer.writeContents(
          outputDirectory: outputDirectory,
          javaPackagePath: nil,
          filename: filename) {
          print("[swift-java] Generated: \(fileNameBase.bold).swift (at \(outputFile)")
        }
      } catch {
        log.warning("Failed to write to Swift thunks: \(filename)")
      }
    }
  }

  public func printSwiftThunkSources(_ printer: inout CodePrinter, decl: ImportedFunc) {
    let stt = SwiftThunkTranslator(self)

    for thunk in stt.render(forFunc: decl) {
      printer.print(thunk)
      printer.println()
    }
  }

  public func printSwiftThunkSources(_ printer: inout CodePrinter, ty: ImportedNominalType) throws {
    let stt = SwiftThunkTranslator(self)

    for thunk in stt.renderThunks(forType: ty) {
      printer.print("\(thunk)")
      printer.print("")
    }
  }

  /// A module contains all static and global functions from the Swift module,
  /// potentially from across multiple swift interfaces.
  public func writeExportedJavaModule(outputDirectory: String) throws {
    var printer = CodePrinter()
    try writeExportedJavaModule(outputDirectory: outputDirectory, printer: &printer)
  }

  public func writeExportedJavaModule(outputDirectory: String, printer: inout CodePrinter) throws {
    printModule(&printer)

    if let file = try printer.writeContents(
      outputDirectory: outputDirectory,
      javaPackagePath: javaPackagePath,
      filename: "\(swiftModuleName).java"
    ) {
      self.log.info("Generated: \(file): \("done".green).")
    }
  }
}

// ==== ---------------------------------------------------------------------------------------------------------------
// MARK: Java/text printing

extension Swift2JavaTranslator {

  /// Render the Java file contents for an imported Swift module.
  ///
  /// This includes any Swift global functions in that module, and some general type information and helpers.
  public func printModule(_ printer: inout CodePrinter) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    printModuleClass(&printer) { printer in

      printStaticLibraryLoad(&printer)

      // TODO: print all "static" methods
      for decl in importedGlobalFuncs {
        printFunctionDowncallMethods(&printer, decl)
      }
    }
  }

  public func printImportedClass(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    printClass(&printer, decl) { printer in
      // Ensure we have loaded the library where the Swift type was declared before we attempt to resolve types in Swift
      printStaticLibraryLoad(&printer)

      // Prepare type metadata, we're going to need these when invoking e.g. initializers so cache them in a static.
      // We call into source swift-java source generated accessors which give us the type of the Swift object:
      // TODO: seems we no longer need the mangled name per se, so avoiding such constant and downcall
      //      printer.printParts(
      //        "public static final String TYPE_MANGLED_NAME = ",
      //        SwiftKitPrinting.renderCallGetSwiftTypeMangledName(module: self.swiftModuleName, nominal: decl),
      //        ";"
      //      )
      printer.printParts(
        """
        public static final SwiftAnyType TYPE_METADATA =
            new SwiftAnyType(\(SwiftKitPrinting.renderCallGetSwiftType(module: self.swiftModuleName, nominal: decl)));
        public final SwiftAnyType $swiftType() {
            return TYPE_METADATA;
        }
        """
      )
      printer.print("")

      // Initializers
      for initDecl in decl.initializers {
        printClassConstructors(&printer, initDecl)
      }

      // Properties
      for varDecl in decl.variables {
        printVariableDowncallMethods(&printer, varDecl)
      }

      // Methods
      for funcDecl in decl.methods {
        printFunctionDowncallMethods(&printer, funcDecl)
      }

      // Helper methods and default implementations
      printHeapObjectToStringMethod(&printer, decl)
    }
  }

  public func printHeader(_ printer: inout CodePrinter) {
    assert(printer.isEmpty)
    printer.print(
      """
      // Generated by jextract-swift
      // Swift module: \(swiftModuleName)

      """
    )
  }

  public func printPackage(_ printer: inout CodePrinter) {
    printer.print(
      """
      package \(javaPackage);

      """
    )
  }

  public func printImports(_ printer: inout CodePrinter) {
    for i in Swift2JavaTranslator.defaultJavaImports {
      printer.print("import \(i);")
    }
    printer.print("")
  }

  public func printClass(
    _ printer: inout CodePrinter, _ decl: ImportedNominalType, body: (inout CodePrinter) -> Void
  ) {
    printer.printTypeDecl("public final class \(decl.javaClassName) implements SwiftHeapObject") {
      printer in
      // ==== Storage of the class
      printClassSelfProperty(&printer, decl)

      // Constants
      printClassConstants(printer: &printer)
      printTypeMappingDecls(&printer)

      // Layout of the class
      printClassMemoryLayout(&printer, decl)

      // Render the 'trace' functions etc
      printTraceFunctionDecls(&printer)

      body(&printer)
    }
  }

  public func printModuleClass(_ printer: inout CodePrinter, body: (inout CodePrinter) -> Void) {
    printer.printTypeDecl("public final class \(swiftModuleName)") { printer in
      printPrivateConstructor(&printer, swiftModuleName)

      // Constants
      printClassConstants(printer: &printer)
      printTypeMappingDecls(&printer)

      // Render the 'trace' functions etc
      printTraceFunctionDecls(&printer)

      printer.print(
        """
        static MemorySegment findOrThrow(String symbol) {
            return SYMBOL_LOOKUP.find(symbol)
                    .orElseThrow(() -> new UnsatisfiedLinkError("unresolved symbol: %s".formatted(symbol)));
        }
        """
      )

      printer.print(
        """
        static MethodHandle upcallHandle(Class<?> fi, String name, FunctionDescriptor fdesc) {
            try {
                return MethodHandles.lookup().findVirtual(fi, name, fdesc.toMethodType());
            } catch (ReflectiveOperationException ex) {
                throw new AssertionError(ex);
            }
        }
        """
      )

      printer.print(
        """
        static MemoryLayout align(MemoryLayout layout, long align) {
            return switch (layout) {
                case PaddingLayout p -> p;
                case ValueLayout v -> v.withByteAlignment(align);
                case GroupLayout g -> {
                    MemoryLayout[] alignedMembers = g.memberLayouts().stream()
                            .map(m -> align(m, align)).toArray(MemoryLayout[]::new);
                    yield g instanceof StructLayout ?
                            MemoryLayout.structLayout(alignedMembers) : MemoryLayout.unionLayout(alignedMembers);
                }
                case SequenceLayout s -> MemoryLayout.sequenceLayout(s.elementCount(), align(s.elementLayout(), align));
            };
        }
        """
      )

      // SymbolLookup.libraryLookup is platform dependent and does not take into account java.library.path
      // https://bugs.openjdk.org/browse/JDK-8311090
      printer.print(
        """
        static final SymbolLookup SYMBOL_LOOKUP = getSymbolLookup();
        private static SymbolLookup getSymbolLookup() {
            if (PlatformUtils.isMacOS()) {
                return SymbolLookup.libraryLookup(System.mapLibraryName(LIB_NAME), LIBRARY_ARENA)
                        .or(SymbolLookup.loaderLookup())
                        .or(Linker.nativeLinker().defaultLookup());
            } else {
                return SymbolLookup.loaderLookup()
                        .or(Linker.nativeLinker().defaultLookup());
            }
        }
        """
      )

      body(&printer)
    }
  }

  private func printClassConstants(printer: inout CodePrinter) {
    printer.print(
      """
      static final String LIB_NAME = "\(swiftModuleName)";
      static final Arena LIBRARY_ARENA = Arena.ofAuto();
      """
    )
  }

  private func printPrivateConstructor(_ printer: inout CodePrinter, _ typeName: String) {
    printer.print(
      """
      private \(typeName)() {
        // Should not be called directly
      }
      """
    )
  }

  /// Print a property where we can store the "self" pointer of a class.
  private func printClassSelfProperty(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printer.print(
      """
      // Pointer to the referred to class instance's "self".
      private final MemorySegment selfMemorySegment;

      public final MemorySegment $memorySegment() {
        return this.selfMemorySegment;
      }
      """
    )
  }

  private func printClassMemoryLayout(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    // TODO: make use of the swift runtime to get the layout
    printer.print(
      """
      private static final GroupLayout $LAYOUT = MemoryLayout.structLayout(
        SWIFT_POINTER
      ).withName("\(decl.swiftTypeName)");

      public final GroupLayout $layout() {
          return $LAYOUT;
      }
      """
    )
  }

  public func printTypeMappingDecls(_ printer: inout CodePrinter) {
    // TODO: use some dictionary for those
    printer.print(
      """
      // TODO: rather than the C ones offer the Swift mappings
      public static final ValueLayout.OfBoolean C_BOOL = ValueLayout.JAVA_BOOLEAN;
      public static final ValueLayout.OfByte C_CHAR = ValueLayout.JAVA_BYTE;
      public static final ValueLayout.OfShort C_SHORT = ValueLayout.JAVA_SHORT;
      public static final ValueLayout.OfInt C_INT = ValueLayout.JAVA_INT;
      public static final ValueLayout.OfLong C_LONG_LONG = ValueLayout.JAVA_LONG;
      public static final ValueLayout.OfFloat C_FLOAT = ValueLayout.JAVA_FLOAT;
      public static final ValueLayout.OfDouble C_DOUBLE = ValueLayout.JAVA_DOUBLE;
      public static final AddressLayout C_POINTER = ValueLayout.ADDRESS
              .withTargetLayout(MemoryLayout.sequenceLayout(java.lang.Long.MAX_VALUE, ValueLayout.JAVA_BYTE));
      public static final ValueLayout.OfLong C_LONG = ValueLayout.JAVA_LONG;
      """
    )
    printer.print("")
    printer.print(
      """
      public static final ValueLayout.OfBoolean SWIFT_BOOL = ValueLayout.JAVA_BOOLEAN;
      public static final ValueLayout.OfByte SWIFT_INT8 = ValueLayout.JAVA_BYTE;
      public static final ValueLayout.OfChar SWIFT_UINT16 = ValueLayout.JAVA_CHAR;
      public static final ValueLayout.OfShort SWIFT_INT16 = ValueLayout.JAVA_SHORT;
      public static final ValueLayout.OfInt SWIFT_INT32 = ValueLayout.JAVA_INT;
      public static final ValueLayout.OfLong SWIFT_INT64 = ValueLayout.JAVA_LONG;
      public static final ValueLayout.OfFloat SWIFT_FLOAT = ValueLayout.JAVA_FLOAT;
      public static final ValueLayout.OfDouble SWIFT_DOUBLE = ValueLayout.JAVA_DOUBLE;
      public static final AddressLayout SWIFT_POINTER = ValueLayout.ADDRESS;
      // On the platform this was generated on, Int was Int64
      public static final SequenceLayout SWIFT_BYTE_ARRAY = MemoryLayout.sequenceLayout(8, ValueLayout.JAVA_BYTE);
      public static final ValueLayout.OfLong SWIFT_INT = SWIFT_INT64;
      public static final ValueLayout.OfLong SWIFT_UINT = SWIFT_INT64;

      public static final AddressLayout SWIFT_SELF = SWIFT_POINTER;
      """
    )
  }

  public func printTraceFunctionDecls(_ printer: inout CodePrinter) {
    printer.print(
      """
      static final boolean TRACE_DOWNCALLS = Boolean.getBoolean("jextract.trace.downcalls");

      static void traceDowncall(Object... args) {
          var ex = new RuntimeException();

          String traceArgs = Arrays.stream(args)
                  .map(Object::toString)
                  .collect(Collectors.joining(", "));
          System.out.printf("[java][%s:%d] Downcall: %s(%s)\\n",
                  ex.getStackTrace()[1].getFileName(),
                  ex.getStackTrace()[1].getLineNumber(),
                  ex.getStackTrace()[1].getMethodName(),
                  traceArgs);
      }

      static void trace(Object... args) {
          var ex = new RuntimeException();

          String traceArgs = Arrays.stream(args)
                  .map(Object::toString)
                  .collect(Collectors.joining(", "));
          System.out.printf("[java][%s:%d] %s: %s\\n",
                  ex.getStackTrace()[1].getFileName(),
                  ex.getStackTrace()[1].getLineNumber(),
                  ex.getStackTrace()[1].getMethodName(),
                  traceArgs);
      }
      """
    )
  }

  public func printClassConstructors(_ printer: inout CodePrinter, _ decl: ImportedFunc) {
    guard let parentName = decl.parent else {
      fatalError("init must be inside a parent type! Was: \(decl)")
    }
    printer.printSeparator(decl.identifier)

    let descClassIdentifier = renderDescClassName(decl)
    printer.printTypeDecl("private static class \(descClassIdentifier)") { printer in
      printFunctionDescriptorValue(&printer, decl)
      printAccessorFunctionAddr(&printer, decl)
      printMethodDowncallHandleForAddrDesc(&printer)
    }

    printClassInitializerConstructors(&printer, decl, parentName: parentName)
  }

  public func printClassInitializerConstructors(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    parentName: TranslatedType
  ) {
    let descClassIdentifier = renderDescClassName(decl)

    printer.print(
      """
      /**
       * Create an instance of {@code \(parentName.unqualifiedJavaTypeName)}.
       *
       \(decl.renderCommentSnippet ?? " *")
       */
      public \(parentName.unqualifiedJavaTypeName)(\(renderJavaParamDecls(decl, paramPassingStyle: .wrapper))) {
        this(/*arena=*/null, \(renderForwardJavaParams(decl, paramPassingStyle: .wrapper)));
      }
      """
    )

    printer.print(
      """
      /**
       * Create an instance of {@code \(parentName.unqualifiedJavaTypeName)}.
       * This instance is managed by the passed in {@link SwiftArena} and may not outlive the arena's lifetime.
       *
       \(decl.renderCommentSnippet ?? " *")
       */
      public \(parentName.unqualifiedJavaTypeName)(SwiftArena arena, \(renderJavaParamDecls(decl, paramPassingStyle: .wrapper))) {
        var mh$ = \(descClassIdentifier).HANDLE;
        try {
            if (TRACE_DOWNCALLS) {
              traceDowncall(\(renderForwardJavaParams(decl, paramPassingStyle: nil)));
            }

            this.selfMemorySegment = (MemorySegment) mh$.invokeExact(\(renderForwardJavaParams(decl, paramPassingStyle: nil)), TYPE_METADATA.$memorySegment());
            if (arena != null) {
                arena.register(this);
            }
        } catch (Throwable ex$) {
            throw new AssertionError("should not reach here", ex$);
        }
      }
      """
    )
  }

  public func printStaticLibraryLoad(_ printer: inout CodePrinter) {
    printer.print(
      """
      static {
          System.loadLibrary("swiftCore");
          System.loadLibrary(LIB_NAME);
      }
      """
    )
  }

  public func printFunctionDowncallMethods(_ printer: inout CodePrinter, _ decl: ImportedFunc) {
    printer.printSeparator(decl.identifier)

    printer.printTypeDecl("private static class \(decl.baseIdentifier)") { printer in
      printFunctionDescriptorValue(&printer, decl)
      printAccessorFunctionAddr(&printer, decl)
      printMethodDowncallHandleForAddrDesc(&printer)
    }

    printFunctionDescriptorMethod(&printer, decl: decl)
    printFunctionMethodHandleMethod(&printer, decl: decl)
    printFunctionAddressMethod(&printer, decl: decl)

    // Render the basic "make the downcall" function
    if decl.hasParent {
      printFuncDowncallMethod(&printer, decl: decl, paramPassingStyle: .memorySegment)
      printFuncDowncallMethod(&printer, decl: decl, paramPassingStyle: .wrapper)
    } else {
      printFuncDowncallMethod(&printer, decl: decl, paramPassingStyle: nil)
    }
  }

  private func printFunctionAddressMethod(
    _ printer: inout CodePrinter,
    decl: ImportedFunc,
    accessorKind: VariableAccessorKind? = nil
  ) {

    let addrName = accessorKind.renderAddrFieldName
    let methodNameSegment = accessorKind.renderMethodNameSegment
    let snippet = decl.renderCommentSnippet ?? "* "

    printer.print(
      """
      /**
       * Address for:
       \(snippet)
       */
      public static MemorySegment \(decl.baseIdentifier)\(methodNameSegment)$address() {
          return \(decl.baseIdentifier).\(addrName);
      }
      """
    )
  }

  private func printFunctionMethodHandleMethod(
    _ printer: inout CodePrinter,
    decl: ImportedFunc,
    accessorKind: VariableAccessorKind? = nil
  ) {
    let handleName = accessorKind.renderHandleFieldName
    let methodNameSegment = accessorKind.renderMethodNameSegment
    let snippet = decl.renderCommentSnippet ?? "* "

    printer.print(
      """
      /**
       * Downcall method handle for:
       \(snippet)
       */
      public static MethodHandle \(decl.baseIdentifier)\(methodNameSegment)$handle() {
          return \(decl.baseIdentifier).\(handleName);
      }
      """
    )
  }

  private func printFunctionDescriptorMethod(
    _ printer: inout CodePrinter,
    decl: ImportedFunc,
    accessorKind: VariableAccessorKind? = nil
  ) {
    let descName = accessorKind.renderDescFieldName
    let methodNameSegment = accessorKind.renderMethodNameSegment
    let snippet = decl.renderCommentSnippet ?? "* "

    printer.print(
      """
      /**
       * Function descriptor for:
       \(snippet)
       */
      public static FunctionDescriptor \(decl.baseIdentifier)\(methodNameSegment)$descriptor() {
          return \(decl.baseIdentifier).\(descName);
      }
      """
    )
  }

  public func printVariableDowncallMethods(_ printer: inout CodePrinter, _ decl: ImportedVariable) {
    printer.printSeparator(decl.identifier)

    printer.printTypeDecl("private static class \(decl.baseIdentifier)") { printer in
      for accessorKind in decl.supportedAccessorKinds {
        guard let accessor = decl.accessorFunc(kind: accessorKind) else {
          log.warning("Skip print for \(accessorKind) of \(decl.identifier)!")
          continue
        }

        printFunctionDescriptorValue(&printer, accessor, accessorKind: accessorKind)
        printAccessorFunctionAddr(&printer, accessor, accessorKind: accessorKind)
        printMethodDowncallHandleForAddrDesc(&printer, accessorKind: accessorKind)
      }
    }

    // First print all the supporting infra
    for accessorKind in decl.supportedAccessorKinds {
      guard let accessor = decl.accessorFunc(kind: accessorKind) else {
        log.warning("Skip print for \(accessorKind) of \(decl.identifier)!")
        continue
      }
      printFunctionDescriptorMethod(&printer, decl: accessor, accessorKind: accessorKind)
      printFunctionMethodHandleMethod(&printer, decl: accessor, accessorKind: accessorKind)
      printFunctionAddressMethod(&printer, decl: accessor, accessorKind: accessorKind)
    }

    // Then print the actual downcall methods
    for accessorKind in decl.supportedAccessorKinds {
      guard let accessor = decl.accessorFunc(kind: accessorKind) else {
        log.warning("Skip print for \(accessorKind) of \(decl.identifier)!")
        continue
      }

      // Render the basic "make the downcall" function
      if decl.hasParent {
        printFuncDowncallMethod(
          &printer, decl: accessor, paramPassingStyle: .memorySegment, accessorKind: accessorKind)
        printFuncDowncallMethod(
          &printer, decl: accessor, paramPassingStyle: .wrapper, accessorKind: accessorKind)
      } else {
        printFuncDowncallMethod(
          &printer, decl: accessor, paramPassingStyle: nil, accessorKind: accessorKind)
      }
    }
  }

  func printAccessorFunctionAddr(
    _ printer: inout CodePrinter, _ decl: ImportedFunc,
    accessorKind: VariableAccessorKind? = nil
  ) {
    var thunkName = SwiftKitPrinting.Names.functionThunk(
      thunkNameRegistry: &self.thunkNameRegistry,
      module: self.swiftModuleName, function: decl)
    thunkName = thunkNameRegistry.deduplicate(name: thunkName)
    printer.print(
      """
      public static final MemorySegment \(accessorKind.renderAddrFieldName) =
        \(self.swiftModuleName).findOrThrow("\(thunkName)");
      """
    )
  }

  func printMethodDowncallHandleForAddrDesc(
    _ printer: inout CodePrinter, accessorKind: VariableAccessorKind? = nil
  ) {
    printer.print(
      """
      public static final MethodHandle \(accessorKind.renderHandleFieldName) = Linker.nativeLinker().downcallHandle(\(accessorKind.renderAddrFieldName), \(accessorKind.renderDescFieldName));
      """
    )
  }

  public func printFuncDowncallMethod(
    _ printer: inout CodePrinter,
    decl: ImportedFunc,
    paramPassingStyle: SelfParameterVariant?,
    accessorKind: VariableAccessorKind? = nil
  ) {
    let returnTy = decl.returnType.javaType

    let maybeReturnCast: String
    if decl.returnType.javaType == .void {
      maybeReturnCast = ""  // nothing to return or cast to
    } else {
      maybeReturnCast = "return (\(returnTy))"
    }

    // TODO: we could copy the Swift method's documentation over here, that'd be great UX
    let javaDocComment: String =
      """
      /**
       * Downcall to Swift:
       \(decl.renderCommentSnippet ?? "* ")
       */
      """

    // An identifier may be "getX", "setX" or just the plain method name
    let identifier = accessorKind.renderMethodName(decl)

    if paramPassingStyle == SelfParameterVariant.wrapper {
      // delegate to the MemorySegment "self" accepting overload
      printer.print(
        """
        \(javaDocComment)
        public \(returnTy) \(identifier)(\(renderJavaParamDecls(decl, paramPassingStyle: .wrapper))) {
          \(maybeReturnCast) \(identifier)(\(renderForwardJavaParams(decl, paramPassingStyle: .wrapper)));
        }
        """
      )
      return
    }

    let needsArena = downcallNeedsConfinedArena(decl)
    let handleName = accessorKind.renderHandleFieldName

    printer.printParts(
      """
      \(javaDocComment)
      public static \(returnTy) \(identifier)(\(renderJavaParamDecls(decl, paramPassingStyle: paramPassingStyle))) {
        var mh$ = \(decl.baseIdentifier).\(handleName);
        \(renderTry(withArena: needsArena))
      """,
      """
          \(renderUpcallHandles(decl))
      """,
      """
          if (TRACE_DOWNCALLS) {
             traceDowncall(\(renderForwardJavaParams(decl, paramPassingStyle: .memorySegment)));
          }
          \(maybeReturnCast) mh$.invokeExact(\(renderForwardJavaParams(decl, paramPassingStyle: paramPassingStyle)));
        } catch (Throwable ex$) {
          throw new AssertionError("should not reach here", ex$);
        }
      }
      """
    )
  }

  public func printPropertyAccessorDowncallMethod(
    _ printer: inout CodePrinter,
    decl: ImportedFunc,
    paramPassingStyle: SelfParameterVariant?
  ) {
    let returnTy = decl.returnType.javaType

    let maybeReturnCast: String
    if decl.returnType.javaType == .void {
      maybeReturnCast = ""  // nothing to return or cast to
    } else {
      maybeReturnCast = "return (\(returnTy))"
    }

    if paramPassingStyle == SelfParameterVariant.wrapper {
      // delegate to the MemorySegment "self" accepting overload
      printer.print(
        """
        /**
         * {@snippet lang=swift :
         * \(/*TODO: make a printSnippet func*/decl.syntax ?? "")
         * }
         */
        public \(returnTy) \(decl.baseIdentifier)(\(renderJavaParamDecls(decl, paramPassingStyle: .wrapper))) {
          \(maybeReturnCast) \(decl.baseIdentifier)(\(renderForwardJavaParams(decl, paramPassingStyle: .wrapper)));
        }
        """
      )
      return
    }

    printer.print(
      """
      /**
       * {@snippet lang=swift :
       * \(/*TODO: make a printSnippet func*/decl.syntax ?? "")
       * }
       */
      public static \(returnTy) \(decl.baseIdentifier)(\(renderJavaParamDecls(decl, paramPassingStyle: paramPassingStyle))) {
        var mh$ = \(decl.baseIdentifier).HANDLE;
        try {
          if (TRACE_DOWNCALLS) {
             traceDowncall(\(renderForwardJavaParams(decl, paramPassingStyle: .memorySegment)));
          }
          \(maybeReturnCast) mh$.invokeExact(\(renderForwardJavaParams(decl, paramPassingStyle: paramPassingStyle)));
        } catch (Throwable ex$) {
          throw new AssertionError("should not reach here", ex$);
        }
      }
      """
    )
  }

  /// Given a function like `init(cap:name:)`, renders a name like `init_cap_name`
  public func renderDescClassName(_ decl: ImportedFunc) -> String {
    var ps: [String] = [decl.baseIdentifier]
    var pCounter = 0

    func nextUniqueParamName() -> String {
      pCounter += 1
      return "p\(pCounter)"
    }

    for p in decl.effectiveParameters(paramPassingStyle: nil) {
      let param = "\(p.effectiveName ?? nextUniqueParamName())"
      ps.append(param)
    }

    let res = ps.joined(separator: "_")
    return res
  }

  /// Do we need to construct an inline confined arena for the duration of the downcall?
  public func downcallNeedsConfinedArena(_ decl: ImportedFunc) -> Bool {
    for p in decl.parameters {
      // We need to detect if any of the parameters is a closure we need to prepare
      // an upcall handle for.
      if p.type.javaType.isSwiftClosure {
        return true
      }
    }

    return false
  }

  public func renderTry(withArena: Bool) -> String {
    if withArena {
      "try (Arena arena = Arena.ofConfined()) {"
    } else {
      "try {"
    }
  }

  public func renderJavaParamDecls(_ decl: ImportedFunc, paramPassingStyle: SelfParameterVariant?) -> String {
    var ps: [String] = []
    var pCounter = 0

    func nextUniqueParamName() -> String {
      pCounter += 1
      return "p\(pCounter)"
    }

    for p in decl.effectiveParameters(paramPassingStyle: paramPassingStyle) {
      let param = "\(p.type.javaType.description) \(p.effectiveName ?? nextUniqueParamName())"
      ps.append(param)
    }

    let res = ps.joined(separator: ", ")
    return res
  }

  // TODO: these are stateless, find new place for them?
  public func renderSwiftParamDecls(_ decl: ImportedFunc, paramPassingStyle: SelfParameterVariant?) -> String {
    var ps: [String] = []
    var pCounter = 0

    func nextUniqueParamName() -> String {
      pCounter += 1
      return "p\(pCounter)"
    }

    for p in decl.effectiveParameters(paramPassingStyle: paramPassingStyle) {
      let firstName = p.firstName ?? "_"
      let secondName = p.secondName ?? p.firstName ?? nextUniqueParamName()

      let param =
        if firstName == secondName {
          // We have to do this to avoid a 'extraneous duplicate parameter name; 'number' already has an argument label' warning
          "\(firstName): \(p.type.swiftTypeName.description)"
        } else {
          "\(firstName) \(secondName): \(p.type.swiftTypeName.description)"
        }
      ps.append(param)
    }

    if paramPassingStyle == .swiftThunkSelf {
      ps.append("_self: Any")
    }

    let res = ps.joined(separator: ", ")
    return res
  }

  public func renderUpcallHandles(_ decl: ImportedFunc) -> String {
    var printer = CodePrinter()
    for p in decl.parameters where p.type.javaType.isSwiftClosure {
      if p.type.javaType == .javaLangRunnable {
        let paramName = p.secondName ?? p.firstName ?? "_"
        let handleDesc = p.type.javaType.prepareClosureDowncallHandle(
          decl: decl, parameter: paramName)
        printer.print(handleDesc)
      }
    }

    return printer.contents
  }

  public func renderForwardJavaParams(_ decl: ImportedFunc, paramPassingStyle: SelfParameterVariant?) -> String {
    var ps: [String] = []
    var pCounter = 0

    func nextUniqueParamName() -> String {
      pCounter += 1
      return "p\(pCounter)"
    }

    for p in decl.effectiveParameters(paramPassingStyle: paramPassingStyle) {
      // FIXME: fix the handling here we're already a memory segment
      let param: String
      if p.effectiveName == "self$" {
        precondition(paramPassingStyle == .memorySegment)
        param = "self$"
      } else {
        param = "\(p.renderParameterForwarding() ?? nextUniqueParamName())"
      }
      ps.append(param)
    }

    // Add the forwarding "self"
    if paramPassingStyle == .wrapper && !decl.isInit {
      ps.append("$memorySegment()")
    }

    return ps.joined(separator: ", ")
  }

  // TODO: these are stateless, find new place for them?
  public func renderForwardSwiftParams(_ decl: ImportedFunc, paramPassingStyle: SelfParameterVariant?) -> String {
    var ps: [String] = []
    var pCounter = 0

    func nextUniqueParamName() -> String {
      pCounter += 1
      return "p\(pCounter)"
    }

    for p in decl.effectiveParameters(paramPassingStyle: paramPassingStyle) {
      if let firstName = p.firstName {
        ps.append("\(firstName): \(p.effectiveName ?? nextUniqueParamName())")
      } else {
        ps.append("\(p.effectiveName ?? nextUniqueParamName())")
      }
    }

    return ps.joined(separator: ", ")
  }

  public func printFunctionDescriptorValue(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    accessorKind: VariableAccessorKind? = nil
  ) {
    let fieldName = accessorKind.renderDescFieldName
    printer.start("public static final FunctionDescriptor \(fieldName) = ")

    let parameterLayoutDescriptors = javaMemoryLayoutDescriptors(
      forParametersOf: decl,
      paramPassingStyle: .pointer
    )

    if decl.returnType.javaType == .void {
      printer.print("FunctionDescriptor.ofVoid(")
      printer.indent()
    } else {
      printer.print("FunctionDescriptor.of(")
      printer.indent()
      printer.print("", .continue)

      // Write return type
      let returnTyIsLastTy = decl.parameters.isEmpty && !decl.hasParent
      if decl.isInit {
        // when initializing, we return a pointer to the newly created object
        printer.print(
          "/* -> */\(ForeignValueLayout.SwiftPointer)", .parameterNewlineSeparator(returnTyIsLastTy)
        )
      } else {
        var returnDesc = decl.returnType.foreignValueLayout
        returnDesc.inlineComment = " -> "
        printer.print(returnDesc, .parameterNewlineSeparator(returnTyIsLastTy))
      }
    }

    // Write all parameters (including synthesized ones, like self)
    for (desc, isLast) in parameterLayoutDescriptors.withIsLast {
      printer.print(desc, .parameterNewlineSeparator(isLast))
    }

    printer.outdent()
    printer.print(");")
  }

  public func printHeapObjectToStringMethod(
    _ printer: inout CodePrinter, _ decl: ImportedNominalType
  ) {
    printer.print(
      """
      @Override
      public String toString() {
          return getClass().getSimpleName() + "(" +
                  SwiftKit.nameOfSwiftType($swiftType().$memorySegment(), true) +
                  ")@" + $memorySegment();
      }
      """)
  }

}
