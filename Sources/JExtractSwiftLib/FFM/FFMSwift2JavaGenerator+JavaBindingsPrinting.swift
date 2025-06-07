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

extension FFMSwift2JavaGenerator {
  func printFunctionDowncallMethods(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    guard let _ = translatedSignature(for: decl) else {
      // Failed to translate. Skip.
      return
    }

    printer.printSeparator(decl.displayName)

    printJavaBindingDescriptorClass(&printer, decl)

    // Render the "make the downcall" functions.
    printJavaBindingWrapperMethod(&printer, decl)
  }

  /// Print FFM Java binding descriptors for the imported Swift API.
  package func printJavaBindingDescriptorClass(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    let translatedSignature = self.translatedSignature(for: decl)!
    // 'try!' because we know 'loweredSignature' can be described with C.
    let cFunc = try! translatedSignature.loweredSignature.cFunctionDecl(cName: thunkName)

    printer.printBraceBlock(
      """
      /**
       * {@snippet lang=c :
       * \(cFunc.description)
       * }
       */
      private static class \(cFunc.name)
      """
    ) { printer in
      printFunctionDescriptorValue(&printer, cFunc)
      printer.print(
        """
        public static final MemorySegment ADDR =
          \(self.swiftModuleName).findOrThrow("\(cFunc.name)");
        public static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
        """
      )
      printJavaBindingDowncallMethod(&printer, cFunc)
    }
  }

  /// Print the 'FunctionDescriptor' of the lowered cdecl thunk.
  func printFunctionDescriptorValue(
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

  func printJavaBindingDowncallMethod(
    _ printer: inout CodePrinter,
    _ cFunc: CFunction
  ) {
    let returnTy = cFunc.resultType.javaType
    let maybeReturn = cFunc.resultType.isVoid ? "" : "return (\(returnTy)) "

    var params: [String] = []
    var args: [String] = []
    for param in cFunc.parameters {
      // ! unwrapping because cdecl lowering guarantees the parameter named.
      params.append("\(param.type.javaType) \(param.name!)")
      args.append(param.name!)
    }
    let paramsStr = params.joined(separator: ", ")
    let argsStr = args.joined(separator: ", ")

    printer.print(
      """
      public static \(returnTy) call(\(paramsStr)) {
        try {
          if (SwiftKit.TRACE_DOWNCALLS) {
            SwiftKit.traceDowncall(\(argsStr));
          }
          \(maybeReturn)HANDLE.invokeExact(\(argsStr));
        } catch (Throwable ex$) {
          throw new AssertionError("should not reach here", ex$);
        }
      }
      """
    )
  }

  /// Print the calling body that forwards all the parameters to the `methodName`,
  /// with adding `SwiftArena.ofAuto()` at the end.
  public func printJavaBindingWrapperMethod(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc) {
    let methodName: String = switch decl.apiKind {
    case .getter: "get\(decl.name.toCamelCase)"
    case .setter: "set\(decl.name.toCamelCase)"
    case .function, .initializer: decl.name
    }

    var modifiers = "public"
    switch decl.functionSignature.selfParameter {
    case .staticMethod, .initializer, nil:
      modifiers.append(" static")
    default:
      break
    }

    let translatedSignature = self.translatedSignature(for: decl)!
    let returnTy = translatedSignature.result.javaResultType

    var paramDecls = translatedSignature.parameters
      .flatMap(\.javaParameters)
      .map { "\($0.type) \($0.name)" }
    if translatedSignature.requiresSwiftArena {
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
      if case .instance(_) =  decl.functionSignature.selfParameter {
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
    _ decl: ImportedFunc
  ) {
    //===  Part 1: prepare temporary arena if needed.
    let translatedSignature = self.translatedSignature(for: decl)!

    if translatedSignature.requiresTemporaryArena {
      printer.print("try(var arena$ = Arena.ofConfined()) {")
      printer.indent();
    }

    //===  Part 2: prepare all arguments.
    var downCallArguments: [String] = []

    // Regular parameters.
    for (i, parameter) in translatedSignature.parameters.enumerated() {
      let original = decl.functionSignature.parameters[i]
      let parameterName = original.parameterName ?? "_\(i)"
      let lowered = parameter.conversion.render(&printer, parameterName)
      downCallArguments.append(lowered)
    }

    // 'self' parameter.
    if let selfParameter = translatedSignature.selfParameter {
      let lowered = selfParameter.conversion.render(&printer, "this")
      downCallArguments.append(lowered)
    }

    // Indirect return receivers.
    for outParameter in translatedSignature.result.outParameters {
      let memoryLayout = renderMemoryLayoutValue(for: outParameter.type)

      let arena = if let className = outParameter.type.className,
         analysis.importedTypes[className] != nil {
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
    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    let downCall = "\(thunkName).call(\(downCallArguments.joined(separator: ", ")))"

    //=== Part 4: Convert the return value.
    if translatedSignature.result.javaResultType == .void {
      printer.print("\(downCall);")
    } else {
      let placeholder: String
      if translatedSignature.result.outParameters.isEmpty {
        placeholder = downCall
      } else {
        // FIXME: Support cdecl thunk returning a value while populating the out parameters.
        printer.print("\(downCall);")
        placeholder = "_result"
      }
      let result = translatedSignature.result.conversion.render(&printer, placeholder)

      if translatedSignature.result.javaResultType != .void {
        printer.print("return \(result);")
      } else {
        printer.print("\(result);")
      }
    }

    if translatedSignature.requiresTemporaryArena {
      printer.outdent()
      printer.print("}")
    }
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
