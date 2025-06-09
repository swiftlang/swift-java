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

import JavaTypes
import SwiftSyntax
import SwiftSyntaxBuilder

package class FFMSwift2JavaGenerator: Swift2JavaGenerator {
  let log: Logger
  let analysis: AnalysisResult
  let swiftModuleName: String
  let javaPackage: String
  let swiftOutputDirectory: String
  let javaOutputDirectory: String
  let swiftStdlibTypes: SwiftStandardLibraryTypes
  let symbolTable: SwiftSymbolTable

  var javaPackagePath: String {
    javaPackage.replacingOccurrences(of: ".", with: "/")
  }

  var thunkNameRegistry: ThunkNameRegistry = ThunkNameRegistry()

  /// Cached Java translation result. 'nil' indicates failed translation.
  var translatedSignatures: [ImportedFunc: TranslatedFunctionSignature?] = [:]

  package init(
    translator: Swift2JavaTranslator,
    javaPackage: String,
    swiftOutputDirectory: String,
    javaOutputDirectory: String
  ) {
    self.log = Logger(label: "ffm-generator", logLevel: translator.log.logLevel)
    self.analysis = translator.result
    self.swiftModuleName = translator.swiftModuleName
    self.javaPackage = javaPackage
    self.swiftOutputDirectory = swiftOutputDirectory
    self.javaOutputDirectory = javaOutputDirectory
    self.symbolTable = translator.symbolTable
    self.swiftStdlibTypes = translator.swiftStdlibTypes
  }

  func generate() throws {
    try writeSwiftThunkSources()
    try writeExportedJavaSources()
  }
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Defaults

extension FFMSwift2JavaGenerator {

  /// Default set Java imports for every generated file
  static let defaultJavaImports: Array<String> = [
    "org.swift.swiftkit.*",
    "org.swift.swiftkit.SwiftKit",
    "org.swift.swiftkit.util.*",

    // Necessary for native calls and type mapping
    "java.lang.foreign.*",
    "java.lang.invoke.*",
    "java.util.Arrays",
    "java.util.stream.Collectors",
    "java.util.concurrent.atomic.*",
    "java.nio.charset.StandardCharsets",
  ]
}

// ==== ---------------------------------------------------------------------------------------------------------------
// MARK: File writing


extension FFMSwift2JavaGenerator {
  package func writeExportedJavaSources() throws {
    var printer = CodePrinter()
    try writeExportedJavaSources(printer: &printer)
  }

  /// Every imported public type becomes a public class in its own file in Java.
  package func writeExportedJavaSources(printer: inout CodePrinter) throws {
    for (_, ty) in analysis.importedTypes.sorted(by: { (lhs, rhs) in lhs.key < rhs.key }) {
      let filename = "\(ty.swiftNominal.name).java"
      log.info("Printing contents: \(filename)")
      printImportedNominal(&printer, ty)

      if let outputFile = try printer.writeContents(
        outputDirectory: javaOutputDirectory,
        javaPackagePath: javaPackagePath,
        filename: filename
      ) {
        print("[swift-java] Generated: \(ty.swiftNominal.name.bold).java (at \(outputFile))")
      }
    }

    do {
      let filename = "\(self.swiftModuleName).java"
      log.info("Printing contents: \(filename)")
      printModule(&printer)

      if let outputFile = try printer.writeContents(
        outputDirectory: javaOutputDirectory,
        javaPackagePath: javaPackagePath,
        filename: filename)
      {
        print("[swift-java] Generated: \(self.swiftModuleName).java (at \(outputFile))")
      }
    }
  }
}

// ==== ---------------------------------------------------------------------------------------------------------------
// MARK: Java/text printing

extension FFMSwift2JavaGenerator {

  /// Render the Java file contents for an imported Swift module.
  ///
  /// This includes any Swift global functions in that module, and some general type information and helpers.
  func printModule(_ printer: inout CodePrinter) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    printModuleClass(&printer) { printer in
      // TODO: print all "static" methods
      for decl in analysis.importedGlobalFuncs {
        self.log.trace("Print imported decl: \(decl)")
        printFunctionDowncallMethods(&printer, decl)
      }
    }
  }

  func printImportedNominal(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    printNominal(&printer, decl) { printer in
      // We use a static field to abuse the initialization order such that by the time we get type metadata,
      // we already have loaded the library where it will be obtained from.
      printer.printParts(
        """
        @SuppressWarnings("unused")
        private static final boolean INITIALIZED_LIBS = initializeLibs();
        static boolean initializeLibs() {
            System.loadLibrary(SwiftKit.STDLIB_DYLIB_NAME);
            System.loadLibrary("SwiftKitSwift");
            System.loadLibrary(LIB_NAME);
            return true;
        }

        public static final SwiftAnyType TYPE_METADATA =
            new SwiftAnyType(\(SwiftKitPrinting.renderCallGetSwiftType(module: self.swiftModuleName, nominal: decl)));
        public final SwiftAnyType $swiftType() {
            return TYPE_METADATA;
        }
        """
      )
      printer.print("")

      // Layout of the class
      printClassMemoryLayout(&printer, decl)

      printer.print("")

      printer.print(
        """
        public \(decl.swiftNominal.name)(MemorySegment segment, SwiftArena arena) {
          super(segment, arena);
        }
        """
      )

      // Initializers
      for initDecl in decl.initializers {
        printFunctionDowncallMethods(&printer, initDecl)
      }

      // Properties
      for accessorDecl in decl.variables {
        printFunctionDowncallMethods(&printer, accessorDecl)
      }

      // Methods
      for funcDecl in decl.methods {
        printFunctionDowncallMethods(&printer, funcDecl)
      }

      // Helper methods and default implementations
      printToStringMethod(&printer, decl)
    }
  }

  func printHeader(_ printer: inout CodePrinter) {
    printer.print(
      """
      // Generated by jextract-swift
      // Swift module: \(swiftModuleName)

      """
    )
  }

  func printPackage(_ printer: inout CodePrinter) {
    printer.print(
      """
      package \(javaPackage);

      """
    )
  }

  func printImports(_ printer: inout CodePrinter) {
    for i in FFMSwift2JavaGenerator.defaultJavaImports {
      printer.print("import \(i);")
    }
    printer.print("")
  }

  func printNominal(
    _ printer: inout CodePrinter, _ decl: ImportedNominalType, body: (inout CodePrinter) -> Void
  ) {
    let parentProtocol: String
    if decl.swiftNominal.isReferenceType {
      parentProtocol = "SwiftHeapObject"
    } else {
      parentProtocol = "SwiftValue"
    }

    printer.printBraceBlock("public final class \(decl.swiftNominal.name) extends SwiftInstance implements \(parentProtocol)") {
      printer in
      // Constants
      printClassConstants(printer: &printer)

      body(&printer)
    }
  }

  func printModuleClass(_ printer: inout CodePrinter, body: (inout CodePrinter) -> Void) {
    printer.printBraceBlock("public final class \(swiftModuleName)") { printer in
      printPrivateConstructor(&printer, swiftModuleName)

      // Constants
      printClassConstants(printer: &printer)

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
            // Ensure Swift and our Lib are loaded during static initialization of the class.
            SwiftKit.loadLibrary("swiftCore");
            SwiftKit.loadLibrary("SwiftKitSwift");
            SwiftKit.loadLibrary(LIB_NAME);

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

  func printClassConstants(printer: inout CodePrinter) {
    printer.print(
      """
      static final String LIB_NAME = "\(swiftModuleName)";
      static final Arena LIBRARY_ARENA = Arena.ofAuto();
      """
    )
  }

  func printPrivateConstructor(_ printer: inout CodePrinter, _ typeName: String) {
    printer.print(
      """
      private \(typeName)() {
        // Should not be called directly
      }

      // Static enum to force initialization
      private static enum Initializer {
        FORCE; // Refer to this to force outer Class initialization (and static{} blocks to trigger)
      }
      """
    )
  }

  private func printClassMemoryLayout(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printer.print(
      """
      public static final GroupLayout $LAYOUT = (GroupLayout) SwiftValueWitnessTable.layoutOfSwiftType(TYPE_METADATA.$memorySegment());
      public final GroupLayout $layout() {
          return $LAYOUT;
      }
      """
    )
  }

  func printToStringMethod(
    _ printer: inout CodePrinter, _ decl: ImportedNominalType
  ) {
    printer.print(
      """
      @Override
      public String toString() {
          return getClass().getSimpleName()
              + "("
              + SwiftKit.nameOfSwiftType($swiftType().$memorySegment(), true)
              + ")@"
              + $memorySegment();
      }
      """)
  }
}

