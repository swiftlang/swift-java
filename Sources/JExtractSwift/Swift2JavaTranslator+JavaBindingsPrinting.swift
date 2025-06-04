//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaTypes

extension Swift2JavaTranslator {
  public func printInitializerDowncallConstructors(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    printer.printSeparator(decl.displayName)

    printJavaBindingDescriptorClass(&printer, decl)

    // Render the "make the downcall" functions.
    printInitializerDowncallConstructor(&printer, decl)
  }

  public func printFunctionDowncallMethods(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    printer.printSeparator(decl.displayName)

    printJavaBindingDescriptorClass(&printer, decl)

    // Render the "make the downcall" functions.
    printFuncDowncallMethod(&printer, decl)
  }

  /// Print FFM Java binding descriptors for the imported Swift API.
  func printJavaBindingDescriptorClass(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    let cFunc = decl.cFunctionDecl(cName: thunkName)

    printer.printBraceBlock("private static class \(cFunc.name)") { printer in
      printFunctionDescriptorValue(&printer, cFunc)
      printer.print(
        """
        public static final MemorySegment ADDR =
          \(self.swiftModuleName).findOrThrow("\(cFunc.name)");
        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
        """
      )
    }
  }

  /// Print the 'FunctionDescriptor' of the lowered cdecl thunk.
  public func printFunctionDescriptorValue(
    _ printer: inout CodePrinter,
    _ cFunc: CFunction
  ) {
    printer.start("public static final FunctionDescriptor DESC = ")

    let isEmptyParam = cFunc.parameters.isEmpty
    if cFunc.resultType.isVoid {
      printer.print("FunctionDescriptor.ofVoid(", isEmptyParam ? .continue : .newLine)
      printer.indent()
    } else {
      printer.print("FunctionDescriptor.of(")
      printer.indent()
      printer.print("/* -> */", .continue)
      printer.print(cFunc.resultType.foreignValueLayout, .parameterNewlineSeparator(isEmptyParam))
    }

    for (param, isLast) in cFunc.parameters.withIsLast {
      printer.print("/* \(param.name ?? "_"): */", .continue)
      printer.print(param.type.foreignValueLayout, .parameterNewlineSeparator(isLast))
    }

    printer.outdent()
    printer.print(");")
  }

  public func printInitializerDowncallConstructor(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    guard let className = decl.parentType?.asNominalTypeDeclaration?.name else {
      return
    }
    let modifiers = "public"

    var paramDecls = decl.translatedSignature.parameters
      .flatMap(\.javaParameters)
      .map { "\($0.type) \($0.name)" }

    assert(decl.translatedSignature.requiresSwiftArena, "constructor always require the SwiftArena")
    paramDecls.append("SwiftArena swiftArena$")

    printer.printBraceBlock(
      """
      /**
       * Create an instance of {@code \(className)}.
       *
       * {@snippet lang=swift :
       * \(decl.signatureString)
       * }
       */
      \(modifiers) \(className)(\(paramDecls.joined(separator: ", ")))
      """
    ) { printer in
      // Call super constructor `SwiftValue(Supplier <MemorySegment>, SwiftArena)`.
      printer.print("super(() -> {")
      printer.indent()
      printDowncall(&printer, decl, isConstructor: true)
      printer.outdent()
      printer.print("}, swiftArena$);")
    }
  }

  /// Print the calling body that forwards all the parameters to the `methodName`,
  /// with adding `SwiftArena.ofAuto()` at the end.
  public func printFuncDowncallMethod(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc) {
    let methodName: String = switch decl.kind {
    case .getter: "get\(decl.name.toCamelCase)"
    case .setter: "set\(decl.name.toCamelCase)"
    case .function: decl.name
    case .initializer: fatalError("initializers must use printInitializerDowncallConstructor()")
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
      .map { "\($0.type) \($0.name)" }
    if decl.translatedSignature.requiresSwiftArena {
      paramDecls.append("SwiftArena swiftArena$")
    }

    // TODO: we could copy the Swift method's documentation over here, that'd be great UX
    printer.printBraceBlock(
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * \(decl.signatureString)
       * }
       */
      \(modifiers) \(returnTy) \(methodName)(\(paramDecls.joined(separator: ", ")))
      """
    ) { printer in
      if case .instance(_) =  decl.swiftSignature.selfParameter {
        // Make sure the object has not been destroyed.
        printer.print("$ensureAlive();")
      }

      printDowncall(&printer, decl)
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
      let memoryLayout = renderMemoryLayoutValue(for: outParameter.type)

      let arena = if let className = outParameter.type.className,
         self.importedTypes[className] != nil {
        // Use passed-in 'SwiftArena' for 'SwiftValue'.
        "swiftArena$"
      } else {
        // Otherwise use the temporary 'Arena'.
        "arena$"
      }

      let varName = "_result" + outParameter.name

      printer.print(
        "MemorySegment \(varName) = \(arena).allocate(\(memoryLayout));"
      )
      downCallArguments.append(varName)
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
      printer.print("return _result;")
    } else if decl.translatedSignature.result.javaResultType == .void {
      printer.print("\(downCall);")
    } else {
      let placeholder = if decl.translatedSignature.result.outParameters.isEmpty {
        downCall
      } else {
        // FIXME: Support cdecl thunk returning a value while populating the out parameters.
        "_result"
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
    // NOTE: 'printer' is used if the conversion wants to cause side-effects.
    // E.g. storing a temporary values into a variable.
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
      return "(\(javaType)) \(placeholder)"
    }
  }
}
