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
import SwiftJavaConfigurationShared
import SwiftJavaJNICore
import SwiftSyntax
import SwiftSyntaxBuilder

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

  /// Duplicate identifier tracking for the current batch of methods being generated.
  var currentJavaIdentifiers: JavaIdentifierFactory = JavaIdentifierFactory()

  /// Which Java class to use for `findOrThrow` native symbol lookup
  package enum SymbolLookupTarget {
    /// Use the generated module class (e.g. `MySwiftLibrary`)
    case module
    /// Use `SwiftRuntime` (for types whose symbols live in the runtime library)
    case swiftRuntime

    func javaClassName(moduleName: String) -> String {
      switch self {
      case .module: moduleName
      case .swiftRuntime: "SwiftRuntime"
      }
    }
  }

  /// Override symbol lookup class for the current type being generated
  var currentSymbolLookup: SymbolLookupTarget = .module

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
    javaOutputDirectory: String,
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
      self.expectedOutputSwiftFileNames = Set(
        translator.inputs.compactMap { (input) -> String? in
          guard let fileName = input.path.split(separator: PATH_SEPARATOR).last else {
            return nil
          }
          guard fileName.hasSuffix(".swift") else {
            return nil
          }
          return String(fileName.replacing(".swift", with: "+SwiftJava.swift"))
        }
      )
      // Also include filtered-out files so SwiftPM gets the empty outputs it expects
      for path in translator.filteredOutPaths {
        guard let fileName = path.split(separator: PATH_SEPARATOR).last else {
          continue
        }
        if fileName.hasSuffix(".swift") {
          self.expectedOutputSwiftFileNames.insert(
            String(fileName.replacing(".swift", with: "+SwiftJava.swift"))
          )
        }
      }
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
  static let defaultJavaImports: [String] = [
    "org.swift.swiftkit.core.*",
    "org.swift.swiftkit.core.util.*",
    "org.swift.swiftkit.ffm.*",
    "org.swift.swiftkit.ffm.generated.*",

    // NonNull, Unsigned and friends
    "org.swift.swiftkit.core.annotations.*",

    // Necessary for native calls and type mapping
    "java.lang.foreign.*",
    "java.lang.invoke.*",
    "java.util.*",
    "java.nio.charset.StandardCharsets",
  ]

  /// Returns the Java class name for a nominal type, applying known-type overrides
  func javaClassName(for decl: ImportedNominalType) -> String {
    if decl.swiftNominal.knownTypeKind == .swiftJavaError {
      return JavaType.swiftJavaErrorException.className!
    }
    return decl.swiftNominal.name
  }
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
    let typesToExport: [(key: String, value: ImportedNominalType)]
    if let singleType = config.singleType {
      typesToExport = analysis.importedTypes
        .filter { $0.key == singleType }
        .sorted(by: { $0.key < $1.key })
    } else {
      typesToExport = analysis.importedTypes
        .sorted(by: { $0.key < $1.key })
    }

    for (_, ty) in typesToExport {
      let javaName = javaClassName(for: ty)
      let filename = "\(javaName).java"
      log.debug("Printing contents: \(filename)")
      printImportedNominal(&printer, ty)

      if let outputFile = try printer.writeContents(
        outputDirectory: javaOutputDirectory,
        javaPackagePath: javaPackagePath,
        filename: filename,
      ) {
        log.info("Generated: \((javaName.bold + ".java").bold) (at \(outputFile.absoluteString))")
      }
    }

    // Skip the module-level .java file when generating for a single type
    if config.singleType == nil {
      let filename = "\(self.swiftModuleName).java"
      log.debug("Printing contents: \(filename)")
      printModule(&printer)

      if let outputFile = try printer.writeContents(
        outputDirectory: javaOutputDirectory,
        javaPackagePath: javaPackagePath,
        filename: filename,
      ) {
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

    self.currentJavaIdentifiers = JavaIdentifierFactory(
      self.analysis.importedGlobalFuncs + self.analysis.importedGlobalVariables
    )

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

    self.currentJavaIdentifiers = JavaIdentifierFactory(
      decl.initializers + decl.variables + decl.methods
    )

    let isErrorType = decl.swiftNominal.knownTypeKind == .swiftJavaError
    self.currentSymbolLookup = isErrorType ? .swiftRuntime : .module

    printNominal(&printer, decl) { printer in
      // We use a static field to abuse the initialization order such that by the time we get type metadata,
      // we already have loaded the library where it will be obtained from.
      printer.printParts(
        """
        @SuppressWarnings("unused")
        private static final boolean INITIALIZED_LIBS = initializeLibs();
        static boolean initializeLibs() {
            SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_CORE);
            SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
            SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
            SwiftLibraries.loadLibraryWithFallbacks(LIB_NAME);
            return true;
        }
        """
      )
      printer.print("")

      // Type metadata (common to all nominal types)
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

      if let printSpecialExtras = self.getSpecialNominalConstructorPrinting(decl) {
        printSpecialExtras(&printer)
      } else {
        // Layout of the class
        printClassMemoryLayout(&printer, decl)

        printer.print("")

        printer.print(
          """
          private \(self.javaClassName(for: decl))(MemorySegment segment, AllocatingSwiftArena arena) {
            super(segment, arena);
          }

          /**
           * Assume that the passed {@code MemorySegment} represents a memory address of a {@link \(self.javaClassName(for: decl))}.
           * <p/>
           * Warnings:
           * <ul>
           *   <li>No checks are performed about the compatibility of the pointed at memory and the actual \(self.javaClassName(for: decl)) types.</li>
           *   <li>This operation does not copy, or retain, the pointed at pointer, so its lifetime must be ensured manually to be valid when wrapping.</li>
           * </ul>
           */
          public static \(self.javaClassName(for: decl)) wrapMemoryAddressUnsafe(MemorySegment selfPointer, AllocatingSwiftArena arena) {
            return new \(self.javaClassName(for: decl))(selfPointer, arena);
          }
          """
        )
      }

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

      // Special helper methods for known types (e.g. Data)
      printSpecificTypeHelpers(&printer, decl)

      if let printSpecialPostExtras = self.getSpecialNominalPostMembersPrinting(decl) {
        printSpecialPostExtras(&printer)
      } else {
        printToStringMethod(&printer, decl)
      }
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
    _ printer: inout CodePrinter,
    _ decl: ImportedNominalType,
    body: (inout CodePrinter) -> Void,
  ) {
    let isErrorType = decl.swiftNominal.knownTypeKind == .swiftJavaError

    let baseClass: String
    let parentProtocol: String
    if isErrorType {
      baseClass = "FFMSwiftErrorInstance"
      // Untyped throws wraps in SwiftJavaError which is a class (heap object)
      parentProtocol = "SwiftHeapObject"
    } else {
      baseClass = "FFMSwiftInstance"
      if decl.swiftNominal.isReferenceType {
        parentProtocol = "SwiftHeapObject"
      } else {
        parentProtocol = "SwiftValue"
      }
    }

    if decl.swiftNominal.isSendable {
      printer.print("@ThreadSafe // Sendable")
    }

    let implementsClause = parentProtocol.isEmpty ? "" : " implements \(parentProtocol)"
    printer.printBraceBlock(
      "public final class \(javaClassName(for: decl)) extends \(baseClass)\(implementsClause)"
    ) {
      printer in
      // Constants
      printClassConstants(printer: &printer)

      body(&printer)
    }
  }

  /// Returns a closure that prints the constructor and related extras for special nominal types
  /// (e.g. error types), or `nil` for normal types that use the default layout + constructor
  func getSpecialNominalConstructorPrinting(_ decl: ImportedNominalType) -> ((inout CodePrinter) -> Void)? {
    if decl.swiftNominal.knownTypeKind == .swiftJavaError {
      return { printer in
        // Error constructor: wrap the opaque pointer so it becomes a pointer-to-reference
        // (matching the convention used by normal class instance thunks)
        printer.print(
          """
          public \(self.javaClassName(for: decl))(MemorySegment errorPointer, AllocatingSwiftArena arena) {
            super(fetchDescription(errorPointer), wrapPointer(errorPointer, arena), arena);
          }
          private static MemorySegment wrapPointer(MemorySegment errorPointer, AllocatingSwiftArena arena) {
            MemorySegment wrapped = arena.allocate(ValueLayout.ADDRESS);
            wrapped.set(ValueLayout.ADDRESS, 0, errorPointer);
            return wrapped;
          }
          """
        )
      }
    }
    return nil
  }

  /// Returns a closure that prints post-members extras for special nominal types
  /// (e.g. `fetchDescription` for error types), or `nil` for normal types that use `toString()`
  func getSpecialNominalPostMembersPrinting(_ decl: ImportedNominalType) -> ((inout CodePrinter) -> Void)? {
    if decl.swiftNominal.knownTypeKind == .swiftJavaError {
      return { printer in
        // Error types inherit toString() from Exception; print fetchDescription helper instead
        self.printSwiftJavaErrorFetchDescriptionMethod(&printer, decl)
      }
    }
    return nil
  }

  func printModuleClass(_ printer: inout CodePrinter, body: (inout CodePrinter) -> Void) {
    printer.printBraceBlock("public final class \(swiftModuleName)") { printer in
      printPrivateConstructor(&printer, swiftModuleName)

      // Constants
      printClassConstants(printer: &printer)

      printer.print(
        """
        public static MemorySegment findOrThrow(String symbol) {
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
                SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_CORE);
                SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
                SwiftLibraries.loadLibraryWithFallbacks(SwiftLibraries.LIB_NAME_SWIFT_RUNTIME_FUNCTIONS);
                SwiftLibraries.loadLibraryWithFallbacks(LIB_NAME);
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
      static final String LIB_NAME = "\(config.nativeLibraryName ?? swiftModuleName)";
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
    _ printer: inout CodePrinter,
    _ decl: ImportedNominalType,
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
      """
    )
  }

  /// Print special helper methods for known types like Foundation.Data
  func printSpecificTypeHelpers(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    if decl.swiftNominal.moduleName == "SwiftRuntimeFunctions" {
      switch decl.swiftNominal.qualifiedName {
      case "Data":
        printFoundationDataHelpers(&printer, decl)
      default:
        break
      }
    }
  }

  /// Print the `fetchDescription` static helper for SwiftJavaError.
  /// This calls the `errorDescription()` downcall to get the error message
  /// for the super constructor
  func printSwiftJavaErrorFetchDescriptionMethod(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    // Find the errorDescription method's thunk name
    let errorDescMethod = decl.methods.first { $0.name == "errorDescription" }
    guard let errorDescMethod, let _ = translatedDecl(for: errorDescMethod) else {
      log.warning("SwiftJavaError: could not find errorDescription method for fetchDescription helper")
      return
    }

    let thunkName = thunkNameRegistry.functionThunkName(decl: errorDescMethod)

    // The descriptor class for errorDescription is already emitted by printFunctionDowncallMethods,
    // so we just reference it here
    printer.print(
      """
      private static String fetchDescription(MemorySegment errorPointer) {
        try (var arena$ = Arena.ofConfined()) {
          // Wrap the raw opaque pointer into a pointer-to-reference for the thunk
          MemorySegment selfPtr = arena$.allocate(ValueLayout.ADDRESS);
          selfPtr.set(ValueLayout.ADDRESS, 0, errorPointer);
          MemorySegment result$ = (MemorySegment) \(thunkName).HANDLE.invokeExact(selfPtr);
          return SwiftStrings.fromCString(result$);
        } catch (Throwable ex) {
          return "Swift error (address: 0x" + Long.toHexString(errorPointer.address()) + ")";
        }
      }
      """
    )
  }

}
