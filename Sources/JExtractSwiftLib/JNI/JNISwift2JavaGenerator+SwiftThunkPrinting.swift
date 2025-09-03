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

import SwiftJNI
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension JNISwift2JavaGenerator {
  func writeSwiftThunkSources() throws {
    var printer = CodePrinter()
    try writeSwiftThunkSources(&printer)
  }

  package func writeSwiftExpectedEmptySources() throws {
    for expectedFileName in self.expectedOutputSwiftFiles {
      logger.trace("Write empty file: \(expectedFileName) ...")

      var printer = CodePrinter()
      printer.print("// Empty file generated on purpose")
      _ = try printer.writeContents(
        outputDirectory: self.swiftOutputDirectory,
        javaPackagePath: nil,
        filename: expectedFileName)
    }
  }

  package func writeSwiftThunkSources(_ printer: inout CodePrinter) throws {
    let moduleFilenameBase = "\(self.swiftModuleName)Module+SwiftJava"
    let moduleFilename = "\(moduleFilenameBase).swift"

    do {
      logger.trace("Printing swift module class: \(moduleFilename)")

      try printGlobalSwiftThunkSources(&printer)

      if let outputFile = try printer.writeContents(
        outputDirectory: self.swiftOutputDirectory,
        javaPackagePath: nil,
        filename: moduleFilename
      ) {
        print("[swift-java] Generated: \(moduleFilenameBase.bold).swift (at \(outputFile))")
        self.expectedOutputSwiftFiles.remove(moduleFilename)
      }

      for (_, ty) in self.analysis.importedTypes.sorted(by: { (lhs, rhs) in lhs.key < rhs.key }) {
        let fileNameBase = "\(ty.swiftNominal.qualifiedName)+SwiftJava"
        let filename = "\(fileNameBase).swift"
        logger.debug("Printing contents: \(filename)")

        do {
          try printNominalTypeThunks(&printer, ty)

          if let outputFile = try printer.writeContents(
            outputDirectory: self.swiftOutputDirectory,
            javaPackagePath: nil,
            filename: filename) {
            print("[swift-java] Generated: \(fileNameBase.bold).swift (at \(outputFile))")
            self.expectedOutputSwiftFiles.remove(filename)
          }
        } catch {
          logger.warning("Failed to write to Swift thunks: \(filename)")
        }
      }
    } catch {
      logger.warning("Failed to write to Swift thunks: \(moduleFilename)")
    }
  }

  private func printJNICache(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    printer.printBraceBlock("enum \(JNICaching.cacheName(for: type))") { printer in
      for enumCase in type.cases {
        guard let translatedCase = translatedEnumCase(for: enumCase) else { continue }
        printer.print("static let \(JNICaching.cacheMemberName(for: enumCase)) = \(renderEnumCaseCacheInit(translatedCase))")
      }
    }
  }

  private func printGlobalSwiftThunkSources(_ printer: inout CodePrinter) throws {
    printHeader(&printer)

    for decl in analysis.importedGlobalFuncs {
      printSwiftFunctionThunk(&printer, decl)
      printer.println()
    }

    for decl in analysis.importedGlobalVariables {
      printSwiftFunctionThunk(&printer, decl)
      printer.println()
    }
  }

  private func printNominalTypeThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) throws {
    printHeader(&printer)

    printJNICache(&printer, type)
    printer.println()

    switch type.swiftNominal.kind {
    case .actor, .class, .enum, .struct:
      printConcreteTypeThunks(&printer, type)
    case .protocol:
      printProtocolThunks(&printer, type)
    }
  }

  private func printConcreteTypeThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    for initializer in type.initializers {
      printSwiftFunctionThunk(&printer, initializer)
      printer.println()
    }

    if type.swiftNominal.kind == .enum {
      printEnumDiscriminator(&printer, type)
      printer.println()

      for enumCase in type.cases {
        printEnumCase(&printer, enumCase)
        printer.println()
      }
    }

    for method in type.methods {
      printSwiftFunctionThunk(&printer, method)
      printer.println()
    }

    for variable in type.variables {
      printSwiftFunctionThunk(&printer, variable)
      printer.println()
    }

    printTypeMetadataAddressThunk(&printer, type)
    printer.println()
    printDestroyFunctionThunk(&printer, type)
  }

  private func printProtocolThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    let protocolName = type.swiftNominal.name
  }


  private func printEnumDiscriminator(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    let selfPointerParam = JavaParameter(name: "selfPointer", type: .long)
    printCDecl(
      &printer,
      javaMethodName: "$getDiscriminator",
      parentName: type.swiftNominal.name,
      parameters: [selfPointerParam],
      resultType: .int
    ) { printer in
      let selfPointer = self.printSelfJLongToUnsafeMutablePointer(
        &printer,
        swiftParentName: type.swiftNominal.name,
        selfPointerParam
      )
      printer.printBraceBlock("switch (\(selfPointer).pointee)") { printer in
        for (idx, enumCase) in type.cases.enumerated() {
          printer.print("case .\(enumCase.name): return \(idx)")
        }
      }
    }
  }

  private func printEnumCase(_ printer: inout CodePrinter, _ enumCase: ImportedEnumCase) {
    guard let translatedCase = self.translatedEnumCase(for: enumCase) else {
      return
    }

    // Print static case initializer
    printSwiftFunctionThunk(&printer, enumCase.caseFunction)
    printer.println()

    // Print getAsCase method
    if !translatedCase.translatedValues.isEmpty {
      printEnumGetAsCaseThunk(&printer, translatedCase)
    }
  }

  private func renderEnumCaseCacheInit(_ enumCase: TranslatedEnumCase) -> String {
      let nativeParametersClassName = "\(javaPackagePath)/\(enumCase.enumName)$\(enumCase.name)$$NativeParameters"
      let methodSignature = MethodSignature(resultType: .void, parameterTypes: enumCase.parameterConversions.map(\.native.javaType))
      let methods = #"[.init(name: "<init>", signature: "\#(methodSignature.mangledName)")]"#

      return #"_JNIMethodIDCache(environment: try! JavaVirtualMachine.shared().environment(), className: "\#(nativeParametersClassName)", methods: \#(methods))"#
  }

  private func printEnumGetAsCaseThunk(
    _ printer: inout CodePrinter,
    _ enumCase: TranslatedEnumCase
  ) {
    printCDecl(
      &printer,
      enumCase.getAsCaseFunction
    ) { printer in
      let selfPointer = enumCase.getAsCaseFunction.nativeFunctionSignature.selfParameter!.conversion.render(&printer, "self")
      let caseNames = enumCase.original.parameters.enumerated().map { idx, parameter in
        parameter.name ?? "_\(idx)"
      }
      let caseNamesWithLet = caseNames.map { "let \($0)" }
      let methodSignature = MethodSignature(resultType: .void, parameterTypes: enumCase.parameterConversions.map(\.native.javaType))
      printer.print(
        """
        guard case .\(enumCase.original.name)(\(caseNamesWithLet.joined(separator: ", "))) = \(selfPointer).pointee else {
          fatalError("Expected enum case '\(enumCase.original.name)', but was '\\(\(selfPointer).pointee)'!")
        }
        let cache$ = \(JNICaching.cacheName(for: enumCase.original.enumType)).\(JNICaching.cacheMemberName(for: enumCase.original))
        let class$ = cache$.javaClass
        let method$ = _JNIMethodIDCache.Method(name: "<init>", signature: "\(methodSignature.mangledName)")
        let constructorID$ = cache$[method$]
        """
      )
      let upcallArguments = zip(enumCase.parameterConversions, caseNames).map { conversion, caseName in
        // '0' is treated the same as a null pointer.
        let nullConversion = !conversion.native.javaType.isPrimitive ? " ?? 0" : ""
        let result = conversion.native.conversion.render(&printer, caseName)
        return "\(result)\(nullConversion)"
      }
      printer.print(
        """
        return withVaList([\(upcallArguments.joined(separator: ", "))]) {
          return environment.interface.NewObjectV(environment, class$, constructorID$, $0)
        }
        """
      )
    }
  }

  private func printSwiftFunctionThunk(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    guard let translatedDecl = translatedDecl(for: decl) else {
      // Failed to translate. Skip.
      return
    }

    printCDecl(
      &printer,
      translatedDecl
    ) { printer in
      self.printFunctionDowncall(&printer, decl)
    }
  }

  private func printFunctionDowncall(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    guard let translatedDecl = self.translatedDecl(for: decl) else {
      fatalError("Cannot print function downcall for a function that can't be translated: \(decl)")
    }
    let nativeSignature = translatedDecl.nativeFunctionSignature

    let tryClause: String = decl.isThrowing ? "try " : ""

    // Regular parameters.
    var arguments = [String]()
    for (idx, parameter) in nativeSignature.parameters.enumerated() {
      let javaParameterName = translatedDecl.translatedFunctionSignature.parameters[idx].parameter.name
      let lowered = parameter.conversion.render(&printer, javaParameterName)
      arguments.append(lowered)
    }

    // Callee
    let callee: String = switch decl.functionSignature.selfParameter {
    case .instance(let swiftSelf):
      nativeSignature.selfParameter!.conversion.render(
        &printer,
        swiftSelf.parameterName ?? "self"
      )
    case .staticMethod(let selfType), .initializer(let selfType):
      "\(selfType)"
    case .none:
      swiftModuleName
    }

    // Build the result
    let result: String
    switch decl.apiKind {
    case .function, .initializer:
      let downcallArguments = zip(
        decl.functionSignature.parameters,
        arguments
      ).map { originalParam, argument in
        let label = originalParam.argumentLabel.map { "\($0): " } ?? ""
        return "\(label)\(argument)"
      }
      .joined(separator: ", ")
      result = "\(tryClause)\(callee).\(decl.name)(\(downcallArguments))"

    case .enumCase:
      let downcallArguments = zip(
        decl.functionSignature.parameters,
        arguments
      ).map { originalParam, argument in
        let label = originalParam.argumentLabel.map { "\($0): " } ?? ""
        return "\(label)\(argument)"
      }

      let associatedValues = !downcallArguments.isEmpty ? "(\(downcallArguments.joined(separator: ", ")))" : ""
      result = "\(callee).\(decl.name)\(associatedValues)"

    case .getter:
      result = "\(tryClause)\(callee).\(decl.name)"

    case .setter:
      guard let newValueArgument = arguments.first else {
        fatalError("Setter did not contain newValue parameter: \(decl)")
      }

      result = "\(callee).\(decl.name) = \(newValueArgument)"
    }

    // Lower the result.
    let innerBody: String
    if !decl.functionSignature.result.type.isVoid {
      let loweredResult = nativeSignature.result.conversion.render(&printer, result)
      innerBody = "return \(loweredResult)"
    } else {
      innerBody = result
    }

    if decl.isThrowing {
      // TODO: Handle classes for dummy value
      let dummyReturn = !nativeSignature.result.javaType.isVoid ? "return \(decl.functionSignature.result.type).jniPlaceholderValue" : ""
      printer.print(
          """
          do {
            \(innerBody)
          } catch {
            environment.throwAsException(error)
            \(dummyReturn)
          }
          """
      )
    } else {
      printer.print(innerBody)
    }
  }

  private func printCDecl(
    _ printer: inout CodePrinter,
    _ translatedDecl: TranslatedFunctionDecl,
    _ body: (inout CodePrinter) -> Void
  ) {
    let nativeSignature = translatedDecl.nativeFunctionSignature
    var parameters = nativeSignature.parameters.flatMap(\.parameters)

    if let selfParameter = nativeSignature.selfParameter {
      parameters += selfParameter.parameters
    }

    parameters += nativeSignature.result.outParameters

    printCDecl(
      &printer,
      javaMethodName: translatedDecl.nativeFunctionName,
      parentName: translatedDecl.parentName,
      parameters: parameters,
      resultType: nativeSignature.result.javaType
    ) { printer in
      body(&printer)
    }
  }

  private func printCDecl(
    _ printer: inout CodePrinter,
    javaMethodName: String,
    parentName: String,
    parameters: [JavaParameter],
    resultType: JavaType,
    _ body: (inout CodePrinter) -> Void
  ) {
    let jniSignature = parameters.reduce(into: "") { signature, parameter in
      signature += parameter.type.jniTypeSignature
    }

    let cName =
      "Java_"
      + self.javaPackage.replacingOccurrences(of: ".", with: "_")
      + "_\(parentName.escapedJNIIdentifier)_"
      + javaMethodName.escapedJNIIdentifier
      + "__"
      + jniSignature.escapedJNIIdentifier

    let translatedParameters = parameters.map {
      "\($0.name): \($0.type.jniTypeName)"
    }

    let thunkParameters =
      [
        "environment: UnsafeMutablePointer<JNIEnv?>!",
        "thisClass: jclass"
      ] + translatedParameters
    let thunkReturnType = resultType != .void ? " -> \(resultType.jniTypeName)" : ""

    // TODO: Think about function overloads
    printer.printBraceBlock(
      """
      @_cdecl("\(cName)")
      func \(cName)(\(thunkParameters.joined(separator: ", ")))\(thunkReturnType)
      """
    ) { printer in
      body(&printer)
    }
  }

  private func printHeader(_ printer: inout CodePrinter) {
    printer.print(
      """
      // Generated by swift-java

      import SwiftJava
      
      """
    )
  }

  private func printTypeMetadataAddressThunk(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    printCDecl(
      &printer,
      javaMethodName: "$typeMetadataAddressDowncall",
      parentName: type.swiftNominal.name,
      parameters: [],
      resultType: .long
    ) { printer in
      printer.print(
        """
        let metadataPointer = unsafeBitCast(\(type.swiftNominal.qualifiedName).self, to: UnsafeRawPointer.self)
        return Int64(Int(bitPattern: metadataPointer)).getJNIValue(in: environment)
        """
      )
    }
  }

  /// Prints the implementation of the destroy function.
  private func printDestroyFunctionThunk(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    let selfPointerParam = JavaParameter(name: "selfPointer", type: .long)
    printCDecl(
      &printer,
      javaMethodName: "$destroy",
      parentName: type.swiftNominal.name,
      parameters: [
        selfPointerParam
      ],
      resultType: .void
    ) { printer in
      let parentName = type.qualifiedName
      let selfVar = self.printSelfJLongToUnsafeMutablePointer(&printer, swiftParentName: parentName, selfPointerParam)
      // Deinitialize the pointer allocated (which will call the VWT destroy method)
      // then deallocate the memory.
      printer.print(
        """
        \(selfVar).deinitialize(count: 1)
        \(selfVar).deallocate()
        """
      )
    }
  }

  /// Print the necessary conversion logic to go from a `jlong` to a `UnsafeMutablePointer<Type>`
  ///
  /// - Returns: name of the created "self" variable
  private func printSelfJLongToUnsafeMutablePointer(
      _ printer: inout CodePrinter,
      swiftParentName: String,
      _ selfPointerParam: JavaParameter
  ) -> String {
    let newSelfParamName = "self$"
    printer.print(
      """
      guard let env$ = environment else {
        fatalError("Missing JNIEnv in downcall to \\(#function)")
      }
      assert(\(selfPointerParam.name) != 0, "\(selfPointerParam.name) memory address was null")
      let selfBits$ = Int(Int64(fromJNI: \(selfPointerParam.name), in: env$))
      guard let \(newSelfParamName) = UnsafeMutablePointer<\(swiftParentName)>(bitPattern: selfBits$) else {
        fatalError("self memory address was null in call to \\(#function)!")
      }
      """
    )
    return newSelfParamName
  }
}
