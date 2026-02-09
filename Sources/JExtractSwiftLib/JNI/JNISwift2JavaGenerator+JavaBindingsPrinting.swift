//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import JavaTypes
import OrderedCollections

// MARK: Defaults

extension JNISwift2JavaGenerator {
  /// Default set Java imports for every generated file
  static let defaultJavaImports: Array<String> = [
    "org.swift.swiftkit.core.*",
    "org.swift.swiftkit.core.util.*",
    "java.util.*",
    "java.util.concurrent.atomic.AtomicBoolean",

    // NonNull, Unsigned and friends
    "org.swift.swiftkit.core.annotations.*"
  ]
}

// MARK: Printing

extension JNISwift2JavaGenerator {
  func writeExportedJavaSources() throws {
    var printer = CodePrinter()
    try writeExportedJavaSources(&printer)
  }

  package func writeExportedJavaSources(_ printer: inout CodePrinter) throws {
    let importedTypes = analysis.importedTypes.sorted(by: { (lhs, rhs) in lhs.key < rhs.key })

    var exportedFileNames: OrderedSet<String> = []

    // Each parent type goes into its own file
    // any nested types are printed inside the body as `static class`
    for (_, ty) in importedTypes.filter({ _, type in type.parent == nil }) {
      let filename = "\(ty.swiftNominal.name).java"
      logger.debug("Printing contents: \(filename)")
      printImportedNominal(&printer, ty)

      if let outputFile = try printer.writeContents(
        outputDirectory: javaOutputDirectory,
        javaPackagePath: javaPackagePath,
        filename: filename
      ) {
        exportedFileNames.append(outputFile.path(percentEncoded: false))
        logger.info("[swift-java] Generated: \(ty.swiftNominal.name.bold).java (at \(outputFile))")
      }
    }

    let filename = "\(self.swiftModuleName).java"
    logger.trace("Printing module class: \(filename)")
    printModule(&printer)

    if let outputFile = try printer.writeContents(
      outputDirectory: javaOutputDirectory,
      javaPackagePath: javaPackagePath,
      filename: filename
    ) {
      exportedFileNames.append(outputFile.path(percentEncoded: false))
      logger.info("[swift-java] Generated: \(self.swiftModuleName).java (at \(outputFile))")
    }

    // Write java sources list file
    if let generatedJavaSourcesListFileOutput = config.generatedJavaSourcesListFileOutput, !exportedFileNames.isEmpty {
      let outputPath = URL(fileURLWithPath: javaOutputDirectory).appending(path: generatedJavaSourcesListFileOutput)
      try exportedFileNames.joined(separator: "\n").write(
        to: outputPath,
        atomically: true,
        encoding: .utf8
      )
      logger.info("Generated file at \(outputPath)")
    }
  }



  private func printModule(_ printer: inout CodePrinter) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    printModuleClass(&printer) { printer in
      printer.print(
        """
        static final String LIB_NAME = "\(swiftModuleName)";
        
        static {
          System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
          System.loadLibrary(LIB_NAME);
        }
        """
      )

      for decl in analysis.importedGlobalFuncs {
        self.logger.trace("Print global function: \(decl)")
        printFunctionDowncallMethods(&printer, decl)
        printer.println()
      }

      for decl in analysis.importedGlobalVariables {
        self.logger.trace("Print global variable: \(decl)")
        printFunctionDowncallMethods(&printer, decl)
        printer.println()
      }
    }
  }

  private func printImportedNominal(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    switch decl.swiftNominal.kind {
    case .actor, .class, .enum, .struct:
      printConcreteType(&printer, decl)
    case .protocol:
      printProtocol(&printer, decl)
    }
  }

  private func printProtocol(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    var extends = [String]()

    // If we cannot generate Swift wrappers
    // that allows the user to implement the wrapped interface in Java
    // then we require only JExtracted types can conform to this.
    if !self.interfaceProtocolWrappers.keys.contains(decl) {
      extends.append("JNISwiftInstance")
    }
    let extendsString = extends.isEmpty ? "" : " extends \(extends.joined(separator: ", "))"

    printer.printBraceBlock("public interface \(decl.swiftNominal.name)\(extendsString)") { printer in
      for initializer in decl.initializers {
        printFunctionDowncallMethods(&printer, initializer, skipMethodBody: true)
        printer.println()
      }

      for method in decl.methods {
        printFunctionDowncallMethods(&printer, method, skipMethodBody: true)
        printer.println()
      }

      for variable in decl.variables {
        printFunctionDowncallMethods(&printer, variable, skipMethodBody: true)
        printer.println()
      }
    }
  }

  private func printConcreteType(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printNominal(&printer, decl) { printer in
      printer.print(
        """
        static final String LIB_NAME = "\(swiftModuleName)";
        
        @SuppressWarnings("unused")
        private static final boolean INITIALIZED_LIBS = initializeLibs();
        static boolean initializeLibs() {
            System.loadLibrary(SwiftLibraries.LIB_NAME_SWIFT_JAVA);
            System.loadLibrary(LIB_NAME);
            return true;
        }
        """
      )

      let nestedTypes = self.analysis.importedTypes.filter { _, type in
        type.parent == decl.swiftNominal
      }

      for nestedType in nestedTypes {
        printConcreteType(&printer, nestedType.value)
        printer.println()
      }

      printer.print(
        """
        /**
        * The designated constructor of any imported Swift types.
        *
        * @param selfPointer  a pointer to the memory containing the value
        * @param swiftArena   the arena this object belongs to. When the arena goes out of scope, this value is destroyed.
        */
        private \(decl.swiftNominal.name)(long selfPointer, SwiftArena swiftArena) {
          SwiftObjects.requireNonZero(selfPointer, "selfPointer");
          this.selfPointer = selfPointer;

          // Only register once we have fully initialized the object since this will need the object pointer.
          swiftArena.register(this);
        }

        /** 
         * Assume that the passed {@code long} represents a memory address of a {@link \(decl.swiftNominal.name)}.
         * <p/>
         * Warnings:
         * <ul>
         *   <li>No checks are performed about the compatibility of the pointed at memory and the actual \(decl.swiftNominal.name) types.</li>
         *   <li>This operation does not copy, or retain, the pointed at pointer, so its lifetime must be ensured manually to be valid when wrapping.</li>
         * </ul>
         */
        public static \(decl.swiftNominal.name) wrapMemoryAddressUnsafe(long selfPointer, SwiftArena swiftArena) {
          return new \(decl.swiftNominal.name)(selfPointer, swiftArena);
        }
        
        public static \(decl.swiftNominal.name) wrapMemoryAddressUnsafe(long selfPointer) {
          return new \(decl.swiftNominal.name)(selfPointer, SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA);
        }
        """
      )

      printer.print(
        """
        /** Pointer to the "self". */
        private final long selfPointer;
        
        /** Used to track additional state of the underlying object, e.g. if it was explicitly destroyed. */
        private final AtomicBoolean $state$destroyed = new AtomicBoolean(false);
        
        public long $memoryAddress() {
          return this.selfPointer;
        }
        
        @Override
        public AtomicBoolean $statusDestroyedFlag() {
          return $state$destroyed;
        }
        """
      )

      printer.println()

      if decl.swiftNominal.kind == .enum {
        printEnumHelpers(&printer, decl)
        printer.println()
      }

      for initializer in decl.initializers {
        printFunctionDowncallMethods(&printer, initializer)
        printer.println()
      }

      for method in decl.methods {
        printFunctionDowncallMethods(&printer, method)
        printer.println()
      }

      for variable in decl.variables {
        printFunctionDowncallMethods(&printer, variable)
        printer.println()
      }

      printToStringMethods(&printer, decl)
      printer.println()

      printSpecificTypeHelpers(&printer, decl)

      printTypeMetadataAddressFunction(&printer, decl)
      printer.println()
      printDestroyFunction(&printer, decl)
    }
  }

  /// Prints helpers for specific types like `Foundation.Date`
  private func printSpecificTypeHelpers(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    guard let knownType = decl.swiftNominal.knownTypeKind else { return }

    switch knownType {
    case .foundationDate, .essentialsDate:
      printFoundationDateHelpers(&printer, decl)

    case .foundationData, .essentialsData:
      printFoundationDataHelpers(&printer, decl)

    default:
      break
    }
  }

  private func printToStringMethods(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printer.printBraceBlock("public String toString()") { printer in
      printer.print(
        """
        return $toString(this.$memoryAddress());
        """
      )
    }
    printer.print("private static native java.lang.String $toString(long selfPointer);")

    printer.println()

    printer.printBraceBlock("public String toDebugString()") { printer in
      printer.print(
        """
        return $toDebugString(this.$memoryAddress());
        """
      )
    }
    printer.print("private static native java.lang.String $toDebugString(long selfPointer);")
  }

  private func printHeader(_ printer: inout CodePrinter) {
    printer.print(
      """
      // Generated by jextract-swift
      // Swift module: \(swiftModuleName)

      """
    )
  }

  private func printPackage(_ printer: inout CodePrinter) {
    printer.print(
      """
      package \(javaPackage);

      """
    )
  }

  private func printImports(_ printer: inout CodePrinter) {
    for i in JNISwift2JavaGenerator.defaultJavaImports {
      printer.print("import \(i);")
    }
    printer.print("")
  }

  private func printNominal(
    _ printer: inout CodePrinter, _ decl: ImportedNominalType, body: (inout CodePrinter) -> Void
  ) {
    if decl.swiftNominal.isSendable {
      printer.print("@ThreadSafe // Sendable")
    }
    var modifiers = ["public"]
    if decl.parent != nil {
      modifiers.append("static")
    }
    modifiers.append("final")
    var implements = ["JNISwiftInstance"]
    implements += decl.inheritedTypes
      .compactMap(\.asNominalTypeDeclaration)
      .filter { $0.kind == .protocol }
      .map(\.name)
    let implementsClause = implements.joined(separator: ", ")
    printer.printBraceBlock("\(modifiers.joined(separator: " ")) class \(decl.swiftNominal.name) implements \(implementsClause)") { printer in
      body(&printer)
    }
  }

  private func printModuleClass(_ printer: inout CodePrinter, body: (inout CodePrinter) -> Void) {
    printer.printBraceBlock("public final class \(swiftModuleName)") { printer in
      body(&printer)
    }
  }

  private func printEnumHelpers(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printEnumDiscriminator(&printer, decl)
    printer.println()
    printEnumCaseInterface(&printer, decl)
    printer.println()
    printEnumStaticInitializers(&printer, decl)
    printer.println()
    printEnumCases(&printer, decl)
  }

  private func printEnumDiscriminator(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printer.printBraceBlock("public enum Discriminator") { printer in
      printer.print(
        decl.cases.map { $0.name.uppercased() }.joined(separator: ",\n")
      )
    }

    // TODO: Consider whether all of these "utility" functions can be printed using our existing printing logic.
    printer.printBraceBlock("public Discriminator getDiscriminator()") { printer in
      printer.print("return Discriminator.values()[$getDiscriminator(this.$memoryAddress())];")
    }
    printer.print("private static native int $getDiscriminator(long self);")
  }

  private func printEnumCaseInterface(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printer.print("public sealed interface Case {}")
    printer.println()

    let requiresSwiftArena = decl.cases.compactMap {
      self.translatedEnumCase(for: $0)
    }.contains(where: \.requiresSwiftArena)

    printer.printBraceBlock("public Case getCase(\(requiresSwiftArena ? "SwiftArena swiftArena$" : ""))") { printer in
      printer.print("Discriminator discriminator = this.getDiscriminator();")
      printer.printBraceBlock("switch (discriminator)") { printer in
        for enumCase in decl.cases {
          guard let translatedCase = self.translatedEnumCase(for: enumCase) else {
            continue
          }
          let arenaArgument = translatedCase.requiresSwiftArena ? "swiftArena$" : ""
          printer.print("case \(enumCase.name.uppercased()): return this.getAs\(enumCase.name.firstCharacterUppercased)(\(arenaArgument)).orElseThrow();")
        }
      }
      printer.print(#"throw new RuntimeException("Unknown discriminator value " + discriminator);"#)
    }
  }

  private func printEnumStaticInitializers(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    for enumCase in decl.cases {
      printFunctionDowncallMethods(&printer, enumCase.caseFunction)
    }
  }

  private func printEnumCases(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    for enumCase in decl.cases {
      guard let translatedCase = self.translatedEnumCase(for: enumCase) else {
        return
      }

      let members = translatedCase.translatedValues.map {
        $0.parameter.renderParameter()
      }

      let caseName = enumCase.name.firstCharacterUppercased

      // Print record
      printer.printBraceBlock("public record \(caseName)(\(members.joined(separator: ", "))) implements Case") { printer in
        let nativeParameters = zip(translatedCase.translatedValues, translatedCase.parameterConversions).flatMap { value, conversion in
          ["\(conversion.native.javaType) \(value.parameter.name)"]
        }

        printer.print("record _NativeParameters(\(nativeParameters.joined(separator: ", "))) {}")
      }

      self.printJavaBindingWrapperMethod(&printer, translatedCase.getAsCaseFunction, skipMethodBody: false)
      printer.println()
    }
  }

  private func printFunctionDowncallMethods(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    skipMethodBody: Bool = false
  ) {
    guard translatedDecl(for: decl) != nil else {
      // Failed to translate. Skip.
      return
    }

    printer.printSeparator(decl.displayName)

    printJavaBindingWrapperHelperClass(&printer, decl)

    printJavaBindingWrapperMethod(&printer, decl, skipMethodBody: skipMethodBody)
  }

  /// Print the helper type container for a user-facing Java API.
  ///
  /// * User-facing functional interfaces.
  private func printJavaBindingWrapperHelperClass(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let translated = self.translatedDecl(for: decl)!
    if translated.functionTypes.isEmpty {
      return
    }

    printer.printBraceBlock(
      """
      public static class \(translated.name)
      """
    ) { printer in
      for functionType in translated.functionTypes {
        printJavaBindingWrapperFunctionTypeHelper(&printer, functionType)
      }
    }
  }

  /// Print "wrapper" functional interface representing a Swift closure type.
  func printJavaBindingWrapperFunctionTypeHelper(
    _ printer: inout CodePrinter,
    _ functionType: TranslatedFunctionType
  ) {
    let apiParams = functionType.parameters.map({ $0.parameter.renderParameter() })

    printer.print(
        """
        @FunctionalInterface
        public interface \(functionType.name) {
          \(functionType.result.javaType) apply(\(apiParams.joined(separator: ", ")));
        }
        """
    )
  }

  private func printJavaBindingWrapperMethod(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    skipMethodBody: Bool
  ) {
    guard let translatedDecl = translatedDecl(for: decl) else {
      fatalError("Decl was not translated, \(decl)")
    }
    printJavaBindingWrapperMethod(&printer, translatedDecl, importedFunc: decl, skipMethodBody: skipMethodBody)
  }

  private func printJavaBindingWrapperMethod(
    _ printer: inout CodePrinter,
    _ translatedDecl: TranslatedFunctionDecl,
    importedFunc: ImportedFunc? = nil,
    skipMethodBody: Bool
  ) {
    var modifiers = ["public"]
    if translatedDecl.isStatic {
      modifiers.append("static")
    }

    let translatedSignature = translatedDecl.translatedFunctionSignature
    let resultType = translatedSignature.resultType.javaType
    var parameters = translatedDecl.translatedFunctionSignature.parameters.map { $0.parameter.renderParameter() }
    let throwsClause = translatedDecl.throwsClause()

    let generics = translatedDecl.translatedFunctionSignature.parameters.reduce(into: [(String, [JavaType])]()) { generics, parameter in
      guard case .generic(let name, let extends) = parameter.parameter.type else {
        return
      }
      generics.append((name, extends))
    }
      .map { "\($0) extends \($1.compactMap(\.className).joined(separator: " & "))" }
      .joined(separator: ", ")

    if !generics.isEmpty {
      modifiers.append("<" + generics + ">")
    }

    var annotationsStr = translatedSignature.annotations.map({ $0.render() }).joined(separator: "\n")
    if !annotationsStr.isEmpty { annotationsStr += "\n" }

    let parametersStr = parameters.joined(separator: ", ")

    // Print default global arena variation
    // If we have enabled javaCallbacks we must emit default
    // arena methods for protocols, as this is what
    // Swift will call into, when you call a interface from Swift.
    let shouldGenerateGlobalArenaVariation = config.effectiveMemoryManagementMode.requiresGlobalArena && translatedSignature.requiresSwiftArena
    let isParentProtocol = importedFunc?.parentType?.asNominalType?.isProtocol ?? false

    if shouldGenerateGlobalArenaVariation {
      if let importedFunc {
        TranslatedDocumentation.printDocumentation(
          importedFunc: importedFunc,
          translatedDecl: translatedDecl,
          in: &printer
        )
      }
      var modifiers = modifiers

      // If we are a protocol, we emit this as default method
      if isParentProtocol {
        modifiers.insert("default", at: 1)
      }

      printer.printBraceBlock("\(annotationsStr)\(modifiers.joined(separator: " ")) \(resultType) \(translatedDecl.name)(\(parametersStr))\(throwsClause)") { printer in
        let globalArenaName = "SwiftMemoryManagement.DEFAULT_SWIFT_JAVA_AUTO_ARENA"
        let arguments = translatedDecl.translatedFunctionSignature.parameters.map(\.parameter.name) + [globalArenaName]
        let call = "\(translatedDecl.name)(\(arguments.joined(separator: ", ")))"
        if translatedDecl.translatedFunctionSignature.resultType.javaType.isVoid {
          printer.print("\(call);")
        } else {
          printer.print("return \(call);")
        }
      }
      printer.println()
    }

    if translatedSignature.requiresSwiftArena {
      parameters.append("SwiftArena swiftArena$")
    }
    if let importedFunc {
      TranslatedDocumentation.printDocumentation(
        importedFunc: importedFunc,
        translatedDecl: translatedDecl,
        in: &printer
      )
    }
    let signature = "\(annotationsStr)\(modifiers.joined(separator: " ")) \(resultType) \(translatedDecl.name)(\(parameters.joined(separator: ", ")))\(throwsClause)"
    if skipMethodBody {
      printer.print("\(signature);")
    } else {
      printer.printBraceBlock(signature) { printer in
        printDowncall(&printer, translatedDecl)
      }

      printNativeFunction(&printer, translatedDecl)
    }
  }

  private func printNativeFunction(_ printer: inout CodePrinter, _ translatedDecl: TranslatedFunctionDecl) {
    let nativeSignature = translatedDecl.nativeFunctionSignature
    let resultType = nativeSignature.result.javaType
    var parameters = nativeSignature.parameters.flatMap(\.parameters)
    if let selfParameter = nativeSignature.selfParameter?.parameters {
      parameters += selfParameter
    }
    parameters += nativeSignature.result.outParameters

    let renderedParameters = parameters.map { javaParameter in
        "\(javaParameter.type) \(javaParameter.name)"
    }.joined(separator: ", ")

    printer.print("private static native \(resultType) \(translatedDecl.nativeFunctionName)(\(renderedParameters));")
  }

  private func printDowncall(
    _ printer: inout CodePrinter,
    _ translatedDecl: TranslatedFunctionDecl
  ) {
    let translatedFunctionSignature = translatedDecl.translatedFunctionSignature

    // Regular parameters.
    var arguments = [String]()
    for parameter in translatedFunctionSignature.parameters {
      let lowered = parameter.conversion.render(&printer, parameter.parameter.name)
      arguments.append(lowered)
    }

    // 'self' parameter.
    if let selfParameter = translatedFunctionSignature.selfParameter {
      let lowered = selfParameter.conversion.render(&printer, "this")
      arguments.append(lowered)
    }

    // Indirect return receivers
    for outParameter in translatedFunctionSignature.resultType.outParameters {
      printer.print("\(outParameter.type) \(outParameter.name) = \(outParameter.allocation.render(type: outParameter.type));")
      arguments.append(outParameter.name)
    }

    //=== Part 3: Downcall.
    // TODO: If we always generate a native method and a "public" method, we can actually choose our own thunk names
    // using the registry?
    let downcall = "\(translatedDecl.parentName).\(translatedDecl.nativeFunctionName)(\(arguments.joined(separator: ", ")))"

    //=== Part 4: Convert the return value.
    if translatedFunctionSignature.resultType.javaType.isVoid {
      printer.print("\(downcall);")
    } else {
      let result = translatedFunctionSignature.resultType.conversion.render(&printer, downcall)
      printer.print("return \(result);")
    }
  }

  private func printTypeMetadataAddressFunction(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    printer.print("private static native long $typeMetadataAddressDowncall();")

    let funcName = "$typeMetadataAddress"
    printer.print("@Override")
    printer.printBraceBlock("public long $typeMetadataAddress()") { printer in
      printer.print(
        """
        long self$ = this.$memoryAddress();
        if (CallTraces.TRACE_DOWNCALLS) {
          CallTraces.traceDowncall("\(type.swiftNominal.name).\(funcName)",
              "this", this,
              "self", self$);
        }
        return \(type.swiftNominal.name).$typeMetadataAddressDowncall();
        """
      )
    }
  }

  /// Prints the destroy function for a `JNISwiftInstance`
  private func printDestroyFunction(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    printer.print("private static native void $destroy(long selfPointer);")

    let funcName = "$createDestroyFunction"
    printer.print("@Override")
    printer.printBraceBlock("public Runnable \(funcName)()") { printer in
      printer.print(
        """
        long self$ = this.$memoryAddress();
        if (CallTraces.TRACE_DOWNCALLS) {
          CallTraces.traceDowncall("\(type.swiftNominal.name).\(funcName)",
              "this", this,
              "self", self$);
        }
        return new Runnable() {
          @Override
          public void run() {
            if (CallTraces.TRACE_DOWNCALLS) {
              CallTraces.traceDowncall("\(type.swiftNominal.name).$destroy", "self", self$);
            }
            \(type.swiftNominal.name).$destroy(self$);
          }
        };
        """
      )
    }
  }

  private func printFoundationDateHelpers(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printer.print(
      """
      /**
       * Converts this wrapped date to a Java {@link java.time.Instant}.
       * <p>
       * This method constructs the {@code Instant} using the underlying {@code double} value
       * representing seconds since the Unix Epoch (January 1, 1970).
       * </p>
       *
       * @return A {@code java.time.Instant} derived from the floating-point timestamp.
       */
      public java.time.Instant toInstant() {
          long seconds = (long) this.getTimeIntervalSince1970();
          long nanos = Math.round((this.getTimeIntervalSince1970() - seconds) * 1_000_000_000);
          return java.time.Instant.ofEpochSecond(seconds, nanos);
      }
      """
    )
    printer.println()
    printer.print(
      """
      /**
       * Initializes a Swift {@code Foundation.Date} from a Java {@link java.time.Instant}.
       *
       * <h3>Warning: Precision Loss</h3>
       * <p>
       * <strong>The input precision will be degraded.</strong>
       * </p>
       * <p>
       * Java's {@code Instant} stores time with <strong>nanosecond</strong> precision (9 decimal places).
       * However, this class stores time as a 64-bit floating-point value.
       * </p>
       * <p>
       * This leaves enough capacity for <strong>microsecond</strong> precision (approx. 6 decimal places).
       * </p>
       * <p>
       * Consequently, the last ~3 digits of the {@code Instant}'s nanosecond field will be
       * truncated or subjected to rounding errors during conversion.
       * </p>
       *
       * @param instant The source timestamp to convert.
       * @return A date derived from the input instant with microsecond precision.
       */
      public static Date fromInstant(java.time.Instant instant, SwiftArena swiftArena$) {
        Objects.requireNonNull(instant, "Instant cannot be null");
        double timeIntervalSince1970 = instant.getEpochSecond() + (instant.getNano() / 1_000_000_000.0);
        return Date.init(timeIntervalSince1970, swiftArena$);
      }
      """
    )
  }

  private func printFoundationDataHelpers(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printer.print(
      """
      /**
       * Creates a new Data instance from a byte array.
       *
       * @param bytes The byte array to copy into the Data
       * @param swiftArena$ The arena for memory management
       * @return A new Data instance containing a copy of the bytes
       */
      public static Data fromByteArray(byte[] bytes, SwiftArena swiftArena$) {
        Objects.requireNonNull(bytes, "bytes cannot be null");
        return Data.init(bytes, swiftArena$);
      }

      """
    )
  }
}
