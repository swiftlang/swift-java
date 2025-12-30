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
import SwiftJavaConfigurationShared
import struct Foundation.URL

package class FFMSwift2JavaGenerator: Swift2JavaGenerator {
  let log: Logger
  let config: Configuration
  let analysis: AnalysisResult
  let swiftModuleName: String
  let javaPackage: String
  let swiftOutputDirectory: String
  let javaOutputDirectory: String
  let lookupContext: SwiftTypeLookupContext

  var javaPackagePath: String {
    javaPackage.replacingOccurrences(of: ".", with: "/")
  }

  var thunkNameRegistry: ThunkNameRegistry = ThunkNameRegistry()

  /// Cached Java translation result. 'nil' indicates failed translation.
  var translatedDecls: [ImportedFunc: TranslatedFunctionDecl?] = [:]

  /// Because we need to write empty files for SwiftPM, keep track which files we didn't write yet,
  /// and write an empty file for those.
  /// 
  /// Since Swift files in SwiftPM builds needs to be unique, we use this fact to flatten paths into plain names here.
  /// For uniqueness checking "did we write this file already", just checking the name should be sufficient.
  var expectedOutputSwiftFileNames: Set<String>

  package init(
    config: Configuration,
    translator: Swift2JavaTranslator,
    javaPackage: String,
    swiftOutputDirectory: String,
    javaOutputDirectory: String
  ) {
    self.log = Logger(label: "ffm-generator", logLevel: translator.log.logLevel)
    self.config = config
    self.analysis = translator.result
    self.swiftModuleName = translator.swiftModuleName
    self.javaPackage = javaPackage
    self.swiftOutputDirectory = swiftOutputDirectory
    self.javaOutputDirectory = javaOutputDirectory
    self.lookupContext = translator.lookupContext

    // If we are forced to write empty files, construct the expected outputs.
    // It is sufficient to use file names only, since SwiftPM requires names to be unique within a module anyway.
    if translator.config.writeEmptyFiles ?? false {
      self.expectedOutputSwiftFileNames = Set(translator.inputs.compactMap { (input) -> String? in
        guard let fileName = input.path.split(separator: PATH_SEPARATOR).last else {
          return nil
        }
        guard fileName.hasSuffix(".swift") else {
          return nil
        }
        return String(fileName.replacing(".swift", with: "+SwiftJava.swift"))
      })
      self.expectedOutputSwiftFileNames.insert("\(translator.swiftModuleName)Module+SwiftJava.swift")
      self.expectedOutputSwiftFileNames.insert("Foundation+SwiftJava.swift")
    } else {
      self.expectedOutputSwiftFileNames = []
    }
  }

  func generate() throws {
    try writeSwiftThunkSources()
    log.info("Generated Swift sources (module: '\(self.swiftModuleName)') in: \(swiftOutputDirectory)/")

    try writeExportedJavaSources()
    log.info("Generated Java sources (package: '\(javaPackage)') in: \(javaOutputDirectory)/")

    try writeSwiftExpectedEmptySources()
  }
}

// ===== --------------------------------------------------------------------------------------------------------------
// MARK: Defaults

extension FFMSwift2JavaGenerator {

  /// Default set Java imports for every generated file
  static let defaultJavaImports: Array<String> = [
    "org.swift.swiftkit.core.*",
    "org.swift.swiftkit.core.util.*",
    "org.swift.swiftkit.ffm.*",

    // NonNull, Unsigned and friends
    "org.swift.swiftkit.core.annotations.*",

    // Necessary for native calls and type mapping
    "java.lang.foreign.*",
    "java.lang.invoke.*",
    "java.util.*",
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
      log.debug("Printing contents: \(filename)")
      printImportedNominal(&printer, ty)

      if let outputFile = try printer.writeContents(
        outputDirectory: javaOutputDirectory,
        javaPackagePath: javaPackagePath,
        filename: filename
      ) {
        log.info("Generated: \((ty.swiftNominal.name.bold + ".java").bold) (at \(outputFile.absoluteString))")
      }
    }

    do {
      let filename = "\(self.swiftModuleName).java"
      log.debug("Printing contents: \(filename)")
      printModule(&printer)

      if let outputFile = try printer.writeContents(
        outputDirectory: javaOutputDirectory,
        javaPackagePath: javaPackagePath,
        filename: filename)
      {
        log.info("Generated: \((self.swiftModuleName + ".java").bold) (at \(outputFile.absoluteString))")
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

      for decl in analysis.importedGlobalVariables {
        self.log.trace("Print imported decl: \(decl)")
        printFunctionDowncallMethods(&printer, decl)
      }

      for decl in analysis.importedGlobalFuncs {
        self.log.trace("Print imported decl: \(decl)")
        printFunctionDowncallMethods(&printer, decl)
      }
    }
  }

  func printImportedNominal(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer) // TODO: we could have some imports be driven from types used in the generated decl

    printNominal(&printer, decl) { printer in
      // We use a static field to abuse the initialization order such that by the time we get type metadata,
      // we already have loaded the library where it will be obtained from.
      printer.printParts(
        """
        @SuppressWarnings("unused")
        private static final boolean INITIALIZED_LIBS = initializeLibs();
        static boolean initializeLibs() {
            // Load swiftCore: try path, then JAR, then /usr/lib/swift on macOS
            try {
                System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_CORE);
            } catch (Throwable e) {
                try {
                    SwiftLibraries.loadResourceLibrary(SwiftLibraries.LIB_NAME_SWIFT_CORE);
                } catch (Throwable e2) {
                    if (PlatformUtils.isMacOS()) {
                        try {
                            System.load("/usr/lib/swift/libswiftCore.dylib");
                        } catch (Throwable e3) {
                            throw new RuntimeException("Failed to load swiftCore from java.library.path, JAR, and /usr/lib/swift", e3);
                        }
                    } else {
                        throw e2;
                    }
                }
            }

            // Load SwiftJava: try path, then JAR
            try {
                System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
            } catch (Throwable e) {
                SwiftLibraries.loadResourceLibrary(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
            }

            // Load SwiftRuntimeFunctions: try path, then JAR
            try {
                System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
            } catch (Throwable e) {
                SwiftLibraries.loadResourceLibrary(SwiftLibraries.LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
            }

            // Load module library: try path, then JAR
            try {
                System.loadLibrary(LIB_NAME);
            } catch (Throwable e) {
                SwiftLibraries.loadResourceLibrary(LIB_NAME);
            }

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
        private \(decl.swiftNominal.name)(MemorySegment segment, AllocatingSwiftArena arena) {
          super(segment, arena);
        }

        /** 
         * Assume that the passed {@code MemorySegment} represents a memory address of a {@link \(decl.swiftNominal.name)}.
         * <p/>
         * Warnings:
         * <ul>
         *   <li>No checks are performed about the compatibility of the pointed at memory and the actual \(decl.swiftNominal.name) types.</li>
         *   <li>This operation does not copy, or retain, the pointed at pointer, so its lifetime must be ensured manually to be valid when wrapping.</li>
         * </ul>
         */
        public static \(decl.swiftNominal.name) wrapMemoryAddressUnsafe(MemorySegment selfPointer, AllocatingSwiftArena swiftArena) {
          return new \(decl.swiftNominal.name)(selfPointer, swiftArena);
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

    if decl.swiftNominal.isSendable {
      printer.print("@ThreadSafe // Sendable")
    }
    printer.printBraceBlock("public final class \(decl.swiftNominal.name) extends FFMSwiftInstance implements \(parentProtocol)") {
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
            if (SwiftLibraries.AUTO_LOAD_LIBS) {
                // Load swiftCore: try path, then JAR, then /usr/lib/swift on macOS
                try {
                    System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_CORE);
                } catch (Throwable e) {
                    try {
                        SwiftLibraries.loadResourceLibrary(SwiftLibraries.LIB_NAME_SWIFT_CORE);
                    } catch (Throwable e2) {
                        if (PlatformUtils.isMacOS()) {
                            try {
                                System.load("/usr/lib/swift/libswiftCore.dylib");
                            } catch (Throwable e3) {
                                throw new RuntimeException("Failed to load swiftCore from java.library.path, JAR, and /usr/lib/swift", e);
                            }
                        } else {
                            throw e2;
                        }
                    }
                }

                // Load SwiftJava: try path, then JAR
                try {
                    System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
                } catch (Throwable e) {
                    SwiftLibraries.loadResourceLibrary(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
                }

                // Load SwiftRuntimeFunctions: try path, then JAR
                try {
                    System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
                } catch (Throwable e) {
                    SwiftLibraries.loadResourceLibrary(SwiftLibraries.LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
                }

                // Load module library: try path, then JAR
                try {
                    System.loadLibrary(LIB_NAME);
                } catch (Throwable e) {
                    SwiftLibraries.loadResourceLibrary(LIB_NAME);
                }
            }

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
              + SwiftRuntime.nameOfSwiftType($swiftType().$memorySegment(), true)
              + ")@"
              + $memorySegment();
      }
      """)
  }
}

