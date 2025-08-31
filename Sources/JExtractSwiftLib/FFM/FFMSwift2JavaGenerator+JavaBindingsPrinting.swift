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

import SwiftJNI

extension FFMSwift2JavaGenerator {
  package func printFunctionDowncallMethods(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    guard let _ = translatedDecl(for: decl) else {
      // Failed to translate. Skip.
      return
    }

    printer.printSeparator(decl.displayName)

    printJavaBindingDescriptorClass(&printer, decl)

    printJavaBindingWrapperHelperClass(&printer, decl)

    // Render the "make the downcall" functions.
    printJavaBindingWrapperMethod(&printer, decl)
  }

  /// Print FFM Java binding descriptors for the imported Swift API.
  package func printJavaBindingDescriptorClass(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let thunkName = thunkNameRegistry.functionThunkName(decl: decl)
    let translated = self.translatedDecl(for: decl)!
    // 'try!' because we know 'loweredSignature' can be described with C.
    let cFunc = try! translated.loweredSignature.cFunctionDecl(cName: thunkName)

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
      printFunctionDescriptorDefinition(&printer, cFunc.resultType, cFunc.parameters)
      printer.print(
        """
        private static final MemorySegment ADDR =
          \(self.swiftModuleName).findOrThrow("\(cFunc.name)");
        private static final MethodHandle HANDLE = Linker.nativeLinker().downcallHandle(ADDR, DESC);
        """
      )
      printJavaBindingDowncallMethod(&printer, cFunc)
      printParameterDescriptorClasses(&printer, cFunc)
    }
  }

  /// Print the 'FunctionDescriptor' of the lowered cdecl thunk.
  func printFunctionDescriptorDefinition(
    _ printer: inout CodePrinter,
    _ resultType: CType,
    _ parameters: [CParameter]
  ) {
    printer.start("private static final FunctionDescriptor DESC = ")

    let isEmptyParam = parameters.isEmpty
    if resultType.isVoid {
      printer.print("FunctionDescriptor.ofVoid(", isEmptyParam ? .continue : .newLine)
      printer.indent()
    } else {
      printer.print("FunctionDescriptor.of(")
      printer.indent()
      printer.print("/* -> */", .continue)
      printer.print(resultType.foreignValueLayout, .parameterNewlineSeparator(isEmptyParam))
    }

    for (param, isLast) in parameters.withIsLast {
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
      let name = param.name! // !-safe, because cdecl lowering guarantees the parameter named.

      let annotationsStr =
        if param.type.javaType.parameterAnnotations.isEmpty {
          ""
        } else {
          param.type.javaType.parameterAnnotations.map({$0.render()}).joined(separator: " ") + " "
        }
      params.append("\(annotationsStr)\(param.type.javaType) \(name)")
      args.append(name)
    }
    let paramsStr = params.joined(separator: ", ")
    let argsStr = args.joined(separator: ", ")

    printer.print(
      """
      public static \(returnTy) call(\(paramsStr)) {
        try {
          if (CallTraces.TRACE_DOWNCALLS) {
            CallTraces.traceDowncall(\(argsStr));
          }
          \(maybeReturn)HANDLE.invokeExact(\(argsStr));
        } catch (Throwable ex$) {
          throw new AssertionError("should not reach here", ex$);
        }
      }
      """
    )
  }

  /// Print required helper classes/interfaces for describing the CFunction.
  ///
  /// * function pointer parameter as a functional interface.
  /// * Unnamed-struct parameter as a record. (unimplemented)
  func printParameterDescriptorClasses(
    _ printer: inout CodePrinter,
    _ cFunc: CFunction
  ) {
    for param in cFunc.parameters {
      switch param.type {
      case .pointer(.function):
        let name = "$\(param.name!)"
        printFunctionPointerParameterDescriptorClass(&printer, name, param.type)
      default:
        continue
      }
    }
  }

  /// Print a class describing a function pointer parameter type.
  ///
  ///   ```java
  ///   class $<parameter-name> {
  ///     @FunctionalInterface
  ///     interface Function {
  ///       <return-type> apply(<parameters>);
  ///     }
  ///     static final MethodDescriptor DESC = FunctionDescriptor.of(...);
  ///     static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);
  ///     static MemorySegment toUpcallStub(Function fi, Arena arena) {
  ///       return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
  ///     }
  ///   }
  ///   ```
  func printFunctionPointerParameterDescriptorClass(
    _ printer: inout CodePrinter,
    _ name: String,
    _ cType: CType
  ) {
    guard case .pointer(.function(let cResultType, let cParameterTypes, variadic: false)) = cType else {
      preconditionFailure("must be a C function pointer type; name=\(name), cType=\(cType)")
    }

    let cParams = cParameterTypes.enumerated().map { i, ty in
      CParameter(name: "_\(i)", type: ty)
    }
    let paramDecls = cParams.map({"\($0.type.javaType) \($0.name!)"})

    printer.printBraceBlock(
      """
      /**
       * {snippet lang=c :
       * \(cType)
       * }
       */
      private static class \(name)
      """
    ) { printer in
      printer.print(
        """
        @FunctionalInterface
        public interface Function {
          \(cResultType.javaType) apply(\(paramDecls.joined(separator: ", ")));
        }
        """
      )
      printFunctionDescriptorDefinition(&printer, cResultType, cParams)
      printer.print(
        """
        private static final MethodHandle HANDLE = SwiftRuntime.upcallHandle(Function.class, "apply", DESC);
        private static MemorySegment toUpcallStub(Function fi, Arena arena) {
          return Linker.nativeLinker().upcallStub(HANDLE.bindTo(fi), DESC, arena);
        }
        """
      )
    }
  }

  /// Print the helper type container for a user-facing Java API.
  ///
  /// * User-facing functional interfaces.
  func printJavaBindingWrapperHelperClass(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let translated = self.translatedDecl(for: decl)!
    let bindingDescriptorName = self.thunkNameRegistry.functionThunkName(decl: decl)
    if translated.functionTypes.isEmpty {
      return
    }

    printer.printBraceBlock(
      """
      public static class \(translated.name)
      """
    ) { printer in
      for functionType in translated.functionTypes {
        printJavaBindingWrapperFunctionTypeHelper(&printer, functionType, bindingDescriptorName)
      }
    }
  }

  /// Print "wrapper" functional interface representing a Swift closure type.
  func printJavaBindingWrapperFunctionTypeHelper(
    _ printer: inout CodePrinter,
    _ functionType: TranslatedFunctionType,
    _ bindingDescriptorName: String
  ) {
    let cdeclDescriptor = "\(bindingDescriptorName).$\(functionType.name)"
    if functionType.isCompatibleWithC {
      // If the user-facing functional interface is C ABI compatible, just extend
      // the lowered function pointer parameter interface.
      printer.print(
        """
        @FunctionalInterface
        public interface \(functionType.name) extends \(cdeclDescriptor).Function {}
        private static MemorySegment $toUpcallStub(\(functionType.name) fi, Arena arena) {
          return \(bindingDescriptorName).$\(functionType.name).toUpcallStub(fi, arena);
        }
        """
      )
    } else {
      // Otherwise, the lambda must be wrapped with the lowered function instance.
      let apiParams = functionType.parameters.flatMap {
        $0.javaParameters.map { param in "\(param.type) \(param.name)" }
      }

      printer.print(
        """
        @FunctionalInterface
        public interface \(functionType.name) {
          \(functionType.result.javaResultType) apply(\(apiParams.joined(separator: ", ")));
        }
        """
      )

      let cdeclParams = functionType.cdeclType.parameters.map( { "\($0.parameterName!)" })

      printer.printBraceBlock(
        """
        private static MemorySegment $toUpcallStub(\(functionType.name) fi, Arena arena)
        """
      ) { printer in
        printer.print(
          """
          return \(cdeclDescriptor).toUpcallStub((\(cdeclParams.joined(separator: ", "))) -> {
          """
        )
        printer.indent()
        var convertedArgs: [String] = []
        for param in functionType.parameters {
          let arg = param.conversion.render(&printer, param.javaParameters[0].name)
          convertedArgs.append(arg)
        }

        let call = "fi.apply(\(convertedArgs.joined(separator: ", ")))"
        let result = functionType.result.conversion.render(&printer, call)
        if functionType.result.javaResultType == .void {
          printer.print("\(result);")
        } else {
          printer.print("return \(result);")
        }
        printer.outdent()
        printer.print("}, arena);")
      }
    }
  }

  /// Print the calling body that forwards all the parameters to the `methodName`,
  /// with adding `SwiftArena.ofAuto()` at the end.
  package func printJavaBindingWrapperMethod(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let translated = self.translatedDecl(for: decl)!
    let methodName = translated.name

    var modifiers = "public"
    switch decl.functionSignature.selfParameter {
    case .staticMethod, .initializer, nil:
      modifiers.append(" static")
    default:
      break
    }

    let translatedSignature = translated.translatedSignature
    let returnTy = translatedSignature.result.javaResultType

    var annotationsStr = translatedSignature.annotations.map({ $0.render() }).joined(separator: "\n")
    if !annotationsStr.isEmpty { annotationsStr += "\n" }

    var paramDecls = translatedSignature.parameters
      .flatMap(\.javaParameters)
      .map { $0.renderParameter() }
    if translatedSignature.requiresSwiftArena {
      paramDecls.append("AllocatingSwiftArena swiftArena$")
    }

    // TODO: we could copy the Swift method's documentation over here, that'd be great UX
    printDeclDocumentation(&printer, decl)
    printer.printBraceBlock(
      """
      \(annotationsStr)\(modifiers) \(returnTy) \(methodName)(\(paramDecls.joined(separator: ", ")))
      """
    ) { printer in
      if case .instance(_) =  decl.functionSignature.selfParameter {
        // Make sure the object has not been destroyed.
        printer.print("$ensureAlive();")
      }

      printDowncall(&printer, decl)
    }
  }

  private func printDeclDocumentation(_ printer: inout CodePrinter, _ decl: ImportedFunc) {
    printer.print(
      """
      /**
       * Downcall to Swift:
       * {@snippet lang=swift :
       * \(decl.signatureString)
       * }
       */
      """
    )
  }

  /// Print the actual downcall to the Swift API.
  ///
  /// This assumes that all the parameters are passed-in with appropriate names.
  package func printDowncall(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    //===  Part 1: prepare temporary arena if needed.
    let translatedSignature = self.translatedDecl(for: decl)!.translatedSignature

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
      guard case .concrete(let type) = outParameter.type else {
        continue
      }
      let memoryLayout = renderMemoryLayoutValue(for: type)

      let arena = if let className = type.className,
         analysis.importedTypes[className] != nil {
        // Use passed-in 'SwiftArena' for 'SwiftValue'.
        "swiftArena$"
      } else {
        // Otherwise use the temporary 'Arena'.
        "arena$"
      }

      // FIXME: use trailing$ convention
      let varName = outParameter.name.isEmpty ? "_result" : "_result_" + outParameter.name

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

extension FFMSwift2JavaGenerator.JavaConversionStep {
  /// Whether the conversion uses SwiftArena.
  var requiresSwiftArena: Bool {
    switch self {
    case .placeholder, .explodedName, .constant, .readMemorySegment:
      return false
    case .constructSwiftValue, .wrapMemoryAddressUnsafe:
      return true

    case .call(let inner, _, _), .cast(let inner, _), .construct(let inner, _),
        .method(let inner, _, _, _), .swiftValueSelfSegment(let inner):
      return inner.requiresSwiftArena

    case .commaSeparated(let list):
      return list.contains(where: { $0.requiresSwiftArena })
    }
  }

  /// Whether the conversion uses temporary Arena.
  var requiresTemporaryArena: Bool {
    switch self {
    case .placeholder, .explodedName, .constant:
      return false
    case .readMemorySegment:
      return true
    case .cast(let inner, _), 
         .construct(let inner, _), 
         .constructSwiftValue(let inner, _), 
         .swiftValueSelfSegment(let inner),
         .wrapMemoryAddressUnsafe(let inner, _):
      return inner.requiresSwiftArena
    case .call(let inner, _, let withArena):
      return withArena || inner.requiresTemporaryArena
    case .method(let inner, _, let args, let withArena):
      return withArena || inner.requiresTemporaryArena || args.contains(where: { $0.requiresTemporaryArena })
    case .commaSeparated(let list):
      return list.contains(where: { $0.requiresTemporaryArena })
    }
  }

  /// Returns the conversion string applied to the placeholder.
  func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
    // NOTE: 'printer' is used if the conversion wants to cause side-effects.
    // E.g. storing a temporary values into a variable.
    switch self {
    case .placeholder:
      return placeholder

    case .explodedName(let component):
      return "\(placeholder)_\(component)"

    case .swiftValueSelfSegment:
      return "\(placeholder).$memorySegment()"

    case .call(let inner, let function, let withArena):
      let inner = inner.render(&printer, placeholder)
      let arenaArg = withArena ? ", arena$" : ""
      return "\(function)(\(inner)\(arenaArg))"

    case .method(let inner, let methodName, let arguments, let withArena):
      let inner = inner.render(&printer, placeholder)
      let args = arguments.map { $0.render(&printer, placeholder) }
      let argsStr = (args + (withArena ? ["arena$"] : [])).joined(separator: " ,")
      return "\(inner).\(methodName)(\(argsStr))"

    case .constructSwiftValue(let inner, let javaType):
      let inner = inner.render(&printer, placeholder)
      return "new \(javaType.className!)(\(inner), swiftArena$)"

    case .wrapMemoryAddressUnsafe(let inner, let javaType):
      let inner = inner.render(&printer, placeholder)
      return "\(javaType.className!).wrapMemoryAddressUnsafe(\(inner), swiftArena$)"

    case .construct(let inner, let javaType):
      let inner = inner.render(&printer, placeholder)
      return "new \(javaType)(\(inner))"

    case .cast(let inner, let javaType):
      let inner = inner.render(&printer, placeholder)
      return "(\(javaType)) \(inner)"

    case .commaSeparated(let list):
      return list.map({ $0.render(&printer, placeholder)}).joined(separator: ", ")

    case .constant(let value):
      return value

    case .readMemorySegment(let inner, let javaType):
      let inner = inner.render(&printer, placeholder)
      return "\(inner).get(\(ForeignValueLayout(javaType: javaType)!), 0)"
    }
  }
}
