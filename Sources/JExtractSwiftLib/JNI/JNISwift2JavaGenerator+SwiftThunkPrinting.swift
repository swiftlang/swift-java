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
    let pendingFileCount = self.expectedOutputSwiftFiles.count
    guard pendingFileCount > 0 else {
      return // no need to write any empty files, yay
    }
    
    print("[swift-java] Write empty [\(self.expectedOutputSwiftFiles.count)] 'expected' files in: \(swiftOutputDirectory)/")
    
    for expectedFileName in self.expectedOutputSwiftFiles {
      logger.debug("Write SwiftPM-'expected' empty file: \(expectedFileName.bold)")


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
        logger.info("Generated: \(moduleFilenameBase.bold).swift (at \(outputFile.absoluteString))")
        self.expectedOutputSwiftFiles.remove(moduleFilename)
      }

      // === All types
      // We have to write all types to their corresponding output file that matches the file they were declared in,
      // because otherwise SwiftPM plugins will not pick up files apropriately -- we expect 1 output +SwiftJava.swift file for every input.
      for group: (key: String, value: [Dictionary<String, ImportedNominalType>.Element]) in Dictionary(grouping: self.analysis.importedTypes, by: { $0.value.sourceFilePath }) {
        logger.warning("Writing types in file group: \(group.key): \(group.value.map(\.key))")

        let importedTypesForThisFile = group.value
          .map(\.value)
          .sorted(by: { $0.qualifiedName < $1.qualifiedName })

        let inputFileName = "\(group.key)".split(separator: "/").last ?? "__Unknown.swift"
        let filename = "\(inputFileName)".replacing(".swift", with: "+SwiftJava.swift")

        for ty in importedTypesForThisFile {
          logger.info("Printing Swift thunks for type: \(ty.qualifiedName.bold)")
          printer.printSeparator("Thunks for \(ty.qualifiedName)")

          do {
            try printNominalTypeThunks(&printer, ty)
          } catch {
            logger.warning("Failed to print to Swift thunks for type'\(ty.qualifiedName)' to '\(filename)', error: \(error)")
          }
          
        }

        logger.warning("Write Swift thunks file: \(filename.bold)")
        do {
          if let outputFile = try printer.writeContents(
            outputDirectory: self.swiftOutputDirectory,
            javaPackagePath: nil,
            filename: filename) {
            logger.info("Done writing Swift thunks to: \(outputFile.absoluteString)")
            self.expectedOutputSwiftFiles.remove(filename)
          }
        } catch {
          logger.warning("Failed to write to Swift thunks: \(filename), error: \(error)")
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

  /// Prints the extension needed to make allow upcalls from Swift to Java for protocols
  private func printSwiftInterfaceWrapper(
    _ printer: inout CodePrinter,
    _ translatedWrapper: JavaInterfaceSwiftWrapper
  ) throws {
    printer.printBraceBlock("protocol \(translatedWrapper.wrapperName): \(translatedWrapper.swiftName)") { printer in
      printer.print("var \(translatedWrapper.javaInterfaceVariableName): \(translatedWrapper.javaInterfaceName) { get }")
    }
    printer.println()
    printer.printBraceBlock("extension \(translatedWrapper.wrapperName)") { printer in
      for function in translatedWrapper.functions {
        printInterfaceWrapperFunctionImpl(&printer, function, inside: translatedWrapper)
        printer.println()
      }

      // FIXME: Add support for protocol variables https://github.com/swiftlang/swift-java/issues/457
//      for variable in translatedWrapper.variables {
//        printerInterfaceWrapperVariable(&printer, variable, inside: translatedWrapper)
//        printer.println()
//      }
    }
  }

  private func printInterfaceWrapperFunctionImpl(
    _ printer: inout CodePrinter,
    _ function: JavaInterfaceSwiftWrapper.Function,
    inside wrapper: JavaInterfaceSwiftWrapper
  ) {
    printer.printBraceBlock(function.swiftDecl.signatureString) { printer in
      let upcallArguments = zip(
        function.originalFunctionSignature.parameters,
        function.parameterConversions
      ).map { param, conversion in
        // Wrap-java does not extract parameter names, so no labels
        conversion.render(&printer, param.parameterName!)
      }

      let tryClause = function.originalFunctionSignature.isThrowing ? "try " : ""
      let javaUpcall = "\(tryClause)\(wrapper.javaInterfaceVariableName).\(function.swiftFunctionName)(\(upcallArguments.joined(separator: ", ")))"

      let resultType = function.originalFunctionSignature.result.type
      let result = function.resultConversion.render(&printer, javaUpcall)
      if resultType.isVoid {
        printer.print(result)
      } else {
        printer.print("return \(result)")
      }
    }
  }

  private func printerInterfaceWrapperVariable(
    _ printer: inout CodePrinter,
    _ variable: JavaInterfaceSwiftWrapper.Variable,
    inside wrapper: JavaInterfaceSwiftWrapper
  ) {
    // FIXME: Add support for variables. This won't get printed yet
    // so we no need to worry about fatalErrors.
    printer.printBraceBlock(variable.swiftDecl.signatureString) { printer in
      printer.printBraceBlock("get") { printer in
        printer.print("fatalError()")
      }

      if let setter = variable.setter {
        printer.printBraceBlock("set") { printer in
          printer.print("fatalError()")
        }
      }
    }
  }

  private func printGlobalSwiftThunkSources(_ printer: inout CodePrinter) throws {
    printHeader(&printer)

    printJNIOnLoad(&printer)

    for decl in analysis.importedGlobalFuncs {
      printSwiftFunctionThunk(&printer, decl)
      printer.println()
    }

    for decl in analysis.importedGlobalVariables {
      printSwiftFunctionThunk(&printer, decl)
      printer.println()
    }
  }

  private func printJNIOnLoad(_ printer: inout CodePrinter) {
    printer.print(
      """
      @_cdecl("JNI_OnLoad")
      func JNI_OnLoad(javaVM: JavaVMPointer, reserved: UnsafeMutableRawPointer) -> jint {
        SwiftJavaRuntimeSupport._JNI_OnLoad(javaVM, reserved)
        return JNI_VERSION_1_6
      }
      """
    )
  }

  private func printNominalTypeThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) throws {
    printHeader(&printer)

    printJNICache(&printer, type)
    printer.println()

    switch type.swiftNominal.kind {
    case .actor, .class, .enum, .struct:
      printConcreteTypeThunks(&printer, type)
    case .protocol:
      try printProtocolThunks(&printer, type)
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

    printToStringMethods(&printer, type)
    printTypeMetadataAddressThunk(&printer, type)
    printer.println()
    printDestroyFunctionThunk(&printer, type)
  }

  private func printProtocolThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) throws {
    guard let protocolWrapper = self.interfaceProtocolWrappers[type] else {
      return
    }

    try printSwiftInterfaceWrapper(&printer, protocolWrapper)
  }

  private func printToStringMethods(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    let selfPointerParam = JavaParameter(name: "selfPointer", type: .long)
    let parentName = type.qualifiedName

    printCDecl(
      &printer,
      javaMethodName: "$toString",
      parentName: type.swiftNominal.qualifiedName,
      parameters: [
        selfPointerParam
      ],
      resultType: .javaLangString
    ) { printer in
      let selfVar = self.printSelfJLongToUnsafeMutablePointer(&printer, swiftParentName: parentName, selfPointerParam)

      printer.print(
        """
        return String(describing: \(selfVar).pointee).getJNIValue(in: environment)
        """
      )
    }

    printer.println()

    printCDecl(
      &printer,
      javaMethodName: "$toDebugString",
      parentName: type.swiftNominal.qualifiedName,
      parameters: [
        selfPointerParam
      ],
      resultType: .javaLangString
    ) { printer in
      let selfVar = self.printSelfJLongToUnsafeMutablePointer(&printer, swiftParentName: parentName, selfPointerParam)

      printer.print(
        """
        return String(reflecting: \(selfVar).pointee).getJNIValue(in: environment)
        """
      )
    }
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
      let nativeParametersClassName = "\(enumCase.enumName)$\(enumCase.name)$_NativeParameters"
      let methodSignature = MethodSignature(resultType: .void, parameterTypes: enumCase.parameterConversions.map(\.native.javaType))

      return renderJNICacheInit(className: nativeParametersClassName, methods: [("<init>", methodSignature)])
  }

  private func renderJNICacheInit(className: String, methods: [(String, MethodSignature)]) -> String {
      let fullClassName = "\(javaPackagePath)/\(className)"
      let methods = methods.map { name, signature in
          #".init(name: "\#(name)", signature: "\#(signature.mangledName)")"#
      }.joined(separator: ",\n")

      return #"_JNIMethodIDCache(className: "\#(fullClassName)", methods: [\#(methods)])"#
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
        let nullConversion = !conversion.native.javaType.isPrimitive ? " ?? nil" : ""
        let result = conversion.native.conversion.render(&printer, caseName)
        return "jvalue(\(conversion.native.javaType.jniFieldName): \(result)\(nullConversion))"
      }
      printer.print(
        """
        let newObjectArgs$: [jvalue] = [\(upcallArguments.joined(separator: ", "))]
        return environment.interface.NewObjectA(environment, class$, constructorID$, newObjectArgs$)
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

    printSwiftFunctionHelperClasses(&printer, decl)

    printCDecl(
      &printer,
      translatedDecl
    ) { printer in
      self.printFunctionDowncall(&printer, decl)
    }
  }


  private func printSwiftFunctionHelperClasses(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc
  ) {
    let protocolParameters = decl.functionSignature.parameters.compactMap { parameter in
      if let concreteType = parameter.type.typeIn(
        genericParameters: decl.functionSignature.genericParameters,
        genericRequirements: decl.functionSignature.genericRequirements
      ) {
        return (parameter, concreteType)
      }

      switch parameter.type {
        case .opaque(let protocolType),
          .existential(let protocolType):
        return (parameter, protocolType)

      default:
        return nil
      }
    }.map { parameter, protocolType in
      // We flatten any composite types
      switch protocolType {
      case .composite(let protocols):
        return (parameter, protocols)

      default:
        return (parameter, [protocolType])
      }
    }

    // For each parameter that is a generic or a protocol,
    // we generate a Swift class that conforms to all of those.
    for (parameter, protocolTypes) in protocolParameters {
      let protocolWrappers: [JavaInterfaceSwiftWrapper] = protocolTypes.compactMap { protocolType in
        guard let importedType = self.asImportedNominalTypeDecl(protocolType),
              let wrapper = self.interfaceProtocolWrappers[importedType]
        else {
          return nil
        }
        return wrapper
      }

      // Make sure we can generate wrappers for all the protocols
      // that the parameter requires
      guard protocolWrappers.count == protocolTypes.count else {
        // We cannot extract a wrapper for this class
        // so it must only be passed in by JExtract instances
        continue
      }

      guard let parameterName = parameter.parameterName else {
        // TODO: Throw
        fatalError()
      }
      let swiftClassName = JNISwift2JavaGenerator.protocolParameterWrapperClassName(
        methodName: decl.name,
        parameterName: parameterName,
        parentName: decl.parentType?.asNominalType?.nominalTypeDecl.qualifiedName ?? swiftModuleName
      )
      let implementingProtocols = protocolWrappers.map(\.wrapperName).joined(separator: ", ")

      printer.printBraceBlock("final class \(swiftClassName): \(implementingProtocols)") { printer in
        let variables: [(String, String)] = protocolWrappers.map { wrapper in
          return (wrapper.javaInterfaceVariableName, wrapper.javaInterfaceName)
        }
        for (name, type) in variables {
          printer.print("let \(name): \(type)")
        }
        printer.println()
        let initializerParameters = variables.map { "\($0): \($1)" }.joined(separator: ", ")

        printer.printBraceBlock("init(\(initializerParameters))") { printer in
          for (name, _) in variables {
            printer.print("self.\(name) = \(name)")
          }
        }
      }
    }
  }

  private func asImportedNominalTypeDecl(_ type: SwiftType) -> ImportedNominalType? {
      self.analysis.importedTypes.first(where: ( { name, nominalType in
        nominalType.swiftType == type
      })).map {
        $0.value
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
    case .subscriptGetter:
      let parameters = arguments.joined(separator: ", ")
      result = "\(callee)[\(parameters)]"
    case .subscriptSetter:
      guard let newValueArgument = arguments.last else {
        fatalError("Setter did not contain newValue parameter: \(decl)")
      }

      var argumentsWithoutNewValue = arguments
      argumentsWithoutNewValue.removeLast()

      let parameters = argumentsWithoutNewValue.joined(separator: ", ")
      result = "\(callee)[\(parameters)] = \(newValueArgument)"
    }

    // Lower the result.
    func innerBody(in printer: inout CodePrinter) -> String {
      let loweredResult = nativeSignature.result.conversion.render(&printer, result)

      if !decl.functionSignature.result.type.isVoid {
        return "return \(loweredResult)"
      } else {
        return loweredResult
      }
    }

    if decl.isThrowing, !decl.isAsync {
      let dummyReturn: String

      if nativeSignature.result.javaType.isVoid {
        dummyReturn = ""
      } else {
        // We assume it is something that implements JavaValue
        dummyReturn = "return \(nativeSignature.result.javaType.swiftTypeName(resolver: { _ in "" })).jniPlaceholderValue"
      }

      printer.print("do {")
      printer.indent()
      printer.print(innerBody(in: &printer))
      printer.outdent()
      printer.print("} catch {")
      printer.indent()
      printer.print(
        """
        environment.throwAsException(error)
        \(dummyReturn)
        """
      )
      printer.outdent()
      printer.print("}")
    } else {
      printer.print(innerBody(in: &printer))
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
      + "_\(parentName.replacingOccurrences(of: ".", with: "$").escapedJNIIdentifier)_"
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
      import CSwiftJavaJNI
      import SwiftJavaRuntimeSupport

      """
    )
  }

  private func printTypeMetadataAddressThunk(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    printCDecl(
      &printer,
      javaMethodName: "$typeMetadataAddressDowncall",
      parentName: type.swiftNominal.qualifiedName,
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
      parentName: type.swiftNominal.qualifiedName,
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

  static func protocolParameterWrapperClassName(
    methodName: String,
    parameterName: String,
    parentName: String?
  ) -> String {
    let parent = if let parentName {
      "\(parentName)_"
    } else {
      ""
    }
    return "_\(parent)\(methodName)_\(parameterName)_Wrapper"
  }
}

extension SwiftNominalTypeDeclaration {
  private var safeProtocolName: String {
    self.qualifiedName.replacingOccurrences(of: ".", with: "_")
  }

  /// The name of the corresponding `@JavaInterface` of this type.
  var javaInterfaceName: String {
    "Java\(safeProtocolName)"
  }

  var javaInterfaceSwiftProtocolWrapperName: String {
    "SwiftJava\(safeProtocolName)Wrapper"
  }

  var javaInterfaceVariableName: String {
    "_\(javaInterfaceName.firstCharacterLowercased)Interface"
  }

  var generatedJavaClassMacroName: String {
    if let parent {
      return "\(parent.generatedJavaClassMacroName).Java\(self.name)"
    }

    return "Java\(self.name)"
  }
}
