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

import JavaTypes

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
      let filename = "\(ty.swiftNominal.name).java"
      log.info("Printing contents: \(filename)")
      printImportedNominal(&printer, ty)

      if let outputFile = try printer.writeContents(
        outputDirectory: outputDirectory,
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
        outputDirectory: outputDirectory,
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

extension Swift2JavaTranslator {

  /// Render the Java file contents for an imported Swift module.
  ///
  /// This includes any Swift global functions in that module, and some general type information and helpers.
  public func printModule(_ printer: inout CodePrinter) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    printModuleClass(&printer) { printer in
      // TODO: print all "static" methods
      for decl in importedGlobalFuncs {
        self.log.trace("Print imported decl: \(decl)")
        printFunctionDowncallMethods(&printer, decl)
      }
    }
  }

  package func printImportedNominal(_ printer: inout CodePrinter, _ decl: ImportedNominalType) {
    printHeader(&printer)
    printPackage(&printer)
    printImports(&printer)

    printNominal(&printer, decl) { printer in
      // Prepare type metadata, we're going to need these when invoking e.g. initializers so cache them in a static.
      // We call into source swift-java source generated accessors which give us the type of the Swift object:
      // TODO: seems we no longer need the mangled name per se, so avoiding such constant and downcall
      //      printer.printParts(
      //        "public static final String TYPE_MANGLED_NAME = ",
      //        SwiftKitPrinting.renderCallGetSwiftTypeMangledName(module: self.swiftModuleName, nominal: decl),
      //        ";"
      //      )

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
        printInitializerDowncallConstructors(&printer, initDecl)
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

  public func printHeader(_ printer: inout CodePrinter) {
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

  package func printNominal(
    _ printer: inout CodePrinter, _ decl: ImportedNominalType, body: (inout CodePrinter) -> Void
  ) {
    let parentProtocol: String
    if decl.swiftNominal.isReferenceType {
      parentProtocol = " implements SwiftHeapObject"
    } else {
      parentProtocol = ""
    }

    printer.printBraceBlock("public final class \(decl.swiftNominal.name) extends SwiftValue\(parentProtocol)") { printer in
      // Constants
      printClassConstants(printer: &printer)

      body(&printer)
    }
  }

  public func printModuleClass(_ printer: inout CodePrinter, body: (inout CodePrinter) -> Void) {
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
      private static final GroupLayout $LAYOUT = (GroupLayout) SwiftValueWitnessTable.layoutOfSwiftType(TYPE_METADATA.$memorySegment());
      public static final GroupLayout $LAYOUT() {
          return $LAYOUT;
      }
      public final GroupLayout $layout() {
          return $LAYOUT;
      }
      """
    )
  }

  public func printInitializerDowncallConstructors(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    printer.printSeparator(decl.displayName)

    let descClassIdentifier = thunkNameRegistry.functionThunkName(decl: decl)
    printer.printBraceBlock("private static class \(descClassIdentifier)") { printer in
      printFunctionDescriptorValue(&printer, decl)
      printFunctionAddrValue(&printer, decl)
      printFunctionHandleValue(&printer)
    }

    // Render the "make the downcall" functions.
    printInitializerDowncallConstructor(&printer, decl, isAutoArenaWrapper: true)
    printInitializerDowncallConstructor(&printer, decl)
  }

  public func printFunctionDowncallMethods(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    printer.printSeparator(decl.displayName)

    let descClassIdentifier = thunkNameRegistry.functionThunkName(decl: decl)
    printer.printBraceBlock("private static class \(descClassIdentifier)") { printer in
      printFunctionDescriptorValue(&printer, decl)
      printFunctionAddrValue(&printer, decl)
      printFunctionHandleValue(&printer)
    }

    // Render the "make the downcall" functions.
    if decl.translatedSignature.requiresSwiftArena {
      printFuncDowncallMethod(&printer, decl, isAutoArenaWrapper: true)
    }
    printFuncDowncallMethod(&printer, decl)
  }

  /// Print the 'FunctionDescriptor' of the Swift API.
  public func printFunctionDescriptorValue(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    printer.start("public static final FunctionDescriptor DESC = ")

    let loweredSignature = decl.loweredSignature
    let loweredParams = loweredSignature.allLoweredParameters
    let resultType = try! CType(cdeclType: loweredSignature.result.cdeclResultType)
    let isEmptyParam = loweredParams.isEmpty
    if resultType.isVoid {
      printer.print("FunctionDescriptor.ofVoid(", isEmptyParam ? .continue : .newLine)
      printer.indent()
    } else {
      printer.print("FunctionDescriptor.of(")
      printer.indent()
      printer.print("/* -> */", .continue)
      printer.print(resultType.foreignValueLayout, .parameterNewlineSeparator(isEmptyParam))
    }

    for (param, isLast) in loweredParams.withIsLast {
      let paramType = try! CType(cdeclType: param.type)
      printer.print("/* \(param.parameterName ?? "_"): */", .continue)
      printer.print(paramType.foreignValueLayout, .parameterNewlineSeparator(isLast))
    }

    printer.outdent()
    printer.print(");")
  }

  func printFunctionAddrValue(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    printer.print(
      """
      public static final MemorySegment ADDR =
        \(self.swiftModuleName).findOrThrow("\(thunkName)");
      """
    )
  }

  func printFunctionHandleValue(
    _ printer: inout CodePrinter
  ) {
    printer.print(
      """
      public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
      """
    )
  }

  public func printInitializerDowncallConstructor(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    isAutoArenaWrapper: Bool = false
  ) {
    guard let className = decl.parentType?.asNominalTypeDeclaration?.name else {
      return
    }
    let modifiers = "public"

    var paramDecls = decl.translatedSignature.parameters
      .flatMap(\.javaParameters)
      .map { "\($0.javaType) \($0.parameterName)" }
      .joined(separator: ", ")
    assert(decl.translatedSignature.requiresSwiftArena, "constructor always require the SwiftArena")
    if !isAutoArenaWrapper {
      paramDecls += ", SwiftArena swiftArena$"
    }

    printer.printBraceBlock(
      """
      /**
       * Create an instance of {@code \(className)}.
       *
      \(decl.renderCommentSnippet ?? " *")
       */
      \(modifiers) \(className)(\(paramDecls))
      """
    ) { printer in
      if !isAutoArenaWrapper {
        // Call super constructor `SwiftValue(Supplier <MemorySegment>, SwiftArena)`.
        printer.print("super(() -> {")
        printer.indent()
        printDowncall(&printer, decl, isConstructor: true)
        printer.outdent()
        printer.print("}, swiftArena$);")
      } else {
        printParameterForwardingWithAutoSwiftArena(&printer, "this", decl)
      }
    }
  }

  /// Print the calling body that forwards all the parameters to the `methodName`,
  /// with adding `SwiftArena.ofAuto()` at the end.
  public func printFuncDowncallMethod(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    isAutoArenaWrapper: Bool = false
  ) {
    let methodName: String = switch decl.kind {
    case .getter: "get\(decl.name.toCamelCase)"
    case .setter: "set\(decl.name.toCamelCase)"
    case .function: decl.name
    case .initializer: fatalError("unreachable")
    }

    var modifiers = "public"
    switch decl.swiftSignature.selfParameter {
    case .staticMethod(_), nil:
      modifiers.append(" static")
    default:
      break
    }

    let returnTy = decl.translatedSignature.result.javaResultType

    var paramDecls = decl.translatedSignature.parameters
      .flatMap(\.javaParameters)
      .map { "\($0.javaType) \($0.parameterName)" }
      .joined(separator: ", ")

    if !isAutoArenaWrapper && decl.translatedSignature.requiresSwiftArena {
      paramDecls += ", SwiftArena swiftArena$"
    }

    // TODO: we could copy the Swift method's documentation over here, that'd be great UX
    printer.printBraceBlock(
      """
      /**
       * Downcall to Swift:
      \(decl.renderCommentSnippet ?? "* ")
       */
      \(modifiers) \(returnTy) \(methodName)(\(paramDecls))
      """
    ) { printer in
      if case .instance(_) =  decl.swiftSignature.selfParameter {
        // Make sure the object has not been destroyed.
        printer.print("$ensureAlive();")
      }

      if !isAutoArenaWrapper {
        printDowncall(&printer, decl)
      } else {
        printParameterForwardingWithAutoSwiftArena(&printer, methodName, decl)
      }
    }
  }

  /// Print the calling body that forwards all the parameters to the `methodName`,
  /// with adding `SwiftArena.ofAuto()` at the end.
  func printParameterForwardingWithAutoSwiftArena(
    _ printer: inout CodePrinter,
    _ methodName: String,
    _ decl: ImportedFunc
  ) {
    var arguments = decl.translatedSignature.parameters
      .flatMap(\.javaParameters)
      .map { $0.parameterName }
    arguments.append("SwiftArena.ofAuto()")

    let call = "\(methodName)(\(arguments.joined(separator: ", ")))"

    if decl.translatedSignature.result.javaResultType == .void || decl.kind == .initializer {
      printer.print("\(call);")
    } else {
      printer.print("return \(call);")
    }
  }

  /// Print the actual downcall to the Swift API.
  ///
  /// This assumes that all the parameters are passed-in with appropriate names.
  package func printDowncall(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
    isConstructor: Bool = false
  ) {
    //===  Part 1: MethodHandle
    let descriptorClassIdentifier = thunkNameRegistry.functionThunkName(decl: decl)
    printer.print(
      "var mh$ = \(descriptorClassIdentifier).HANDLE;"
    )

    let tryHead = if decl.translatedSignature.requiresTemporaryArena {
      "try(var arena$ = Arena.ofConfined()) {"
    } else {
      "try {"
    }
    printer.print(tryHead);
    printer.indent();

    //===  Part 2: prepare all arguments.
    var downCallArguments: [String] = []

    // Regular parameters.
    for (i, parameter) in decl.translatedSignature.parameters.enumerated() {
      let original = decl.swiftSignature.parameters[i]
      let parameterName = original.parameterName ?? "_\(i)"
      let converted = parameter.conversion.render(&printer, parameterName)
      let lowered: String
      if parameter.conversion.isTrivial {
        lowered = converted
      } else {
        // Store the conversion to a temporary variable.
        lowered = "\(parameterName)$"
        printer.print("var \(lowered) = \(converted);")
      }
      downCallArguments.append(lowered)
    }

    // 'self' parameter.
    if let selfParameter = decl.translatedSignature.selfParameter {
      let lowered = selfParameter.conversion.render(&printer, "this")
      downCallArguments.append(lowered)
    }

    // Indirect return receivers.
    for outParameter in decl.translatedSignature.result.outParameters {
      let memoryLayout = renderMemoryLayoutValue(for: outParameter.javaType)

      let arena = if let className = outParameter.javaType.className,
         self.importedTypes[className] != nil {
        // Use passed-in 'SwiftArena' for 'SwiftValue'.
        "swiftArena$"
      } else {
        // Otherwise use the temporary 'Arena'.
        "arena$"
      }

      printer.print(
        "MemorySegment \(outParameter.parameterName) = \(arena).allocate(\(memoryLayout));"
      )
      downCallArguments.append(outParameter.parameterName)
    }

    //=== Part 3: Downcall.
    printer.print(
      """
      if (SwiftKit.TRACE_DOWNCALLS) {
          SwiftKit.traceDowncall(\(downCallArguments.joined(separator: ", ")));
      }
      """
    )
    let downCall = "mh$.invokeExact(\(downCallArguments.joined(separator: ", ")))"

    //=== Part 4: Convert the return value.
    if isConstructor {
      // For constructors, the caller expects the "self" memory segment.
      printer.print("\(downCall);")
      let outParameterName = decl.translatedSignature.result.outParameters[0].parameterName
      printer.print("return \(outParameterName);")
    } else if decl.translatedSignature.result.javaResultType == .void {
      printer.print("\(downCall);")
    } else {
      let placeholder = if !decl.translatedSignature.result.outParameters.isEmpty {
        "_result"
      } else {
        downCall
      }
      let result = decl.translatedSignature.result.conversion.render(&printer, placeholder)

      if decl.translatedSignature.result.javaResultType != .void {
        printer.print("return \(result);")
      } else {
        printer.print("\(result);")
      }
    }

    printer.outdent()
    printer.print(
      """
      } catch (Throwable ex$) {
        throw new AssertionError("should not reach here", ex$);
      }
      """
    )
  }

  func renderMemoryLayoutValue(for javaType: JavaType) -> String {
    if let layout = ForeignValueLayout(javaType: javaType) {
      return layout.description
    } else if case .class(package: _, name: let customClass) = javaType {
      return ForeignValueLayout(customType: customClass).description
    } else {
      fatalError("renderMemoryLayoutValue not supported for \(javaType)")
    }
  }

  package func printToStringMethod(
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

extension JavaConversionStep {
  /// Whether the conversion uses SwiftArena.
  var requiresSwiftArena: Bool {
    switch self {
    case .pass, .swiftValueSelfSegment, .construct, .cast, .call:
      return false
    case .constructSwiftValue:
      return true
    }
  }

  /// Whether the conversion uses temporary Arena.
  var requiresTemporaryArena: Bool {
    switch self {
    case .pass, .swiftValueSelfSegment, .construct, .constructSwiftValue, .cast:
      return false
    case .call(_, let withArena):
      return withArena
    }
  }

  /// Whether if the result evaluation is trivial.
  ///
  /// If this is false, it's advised to store it to a variable if it's used multiple times
  var isTrivial: Bool {
    switch self {
    case .pass, .swiftValueSelfSegment:
      return true
    case .cast, .construct, .constructSwiftValue, .call:
      return false
    }
  }

  /// Returns the conversion string applied to the placeholder.
  func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
    switch self {
    case .pass:
      return placeholder

    case .swiftValueSelfSegment:
      return "\(placeholder).$memorySegment()"

    case .call(let function, let withArena):
      let arenaArg = withArena ? ", arena$" : ""
      return "\(function)(\(placeholder)\(arenaArg))"

    case .constructSwiftValue(let javaType):
      return "new \(javaType.className!)(\(placeholder), swiftArena$)"

    case .construct(let javaType):
      return "new \(javaType)(\(placeholder))"

    case .cast(let javaType):
      return "(\(javaType))\(placeholder)"
    }
  }
}
