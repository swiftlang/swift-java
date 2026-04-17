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
import SwiftJavaJNICore
import SwiftSyntax

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
    let pendingFileCount = self.expectedOutputSwiftFileNames.count
    guard pendingFileCount > 0 else {
      return // no need to write any empty files, yay
    }

    logger.info(
      "Write empty [\(self.expectedOutputSwiftFileNames.count)] 'expected' files in: \(swiftOutputDirectory)/"
    )

    for expectedFileName in self.expectedOutputSwiftFileNames {
      logger.info("Write SwiftPM-'expected' empty file: \(expectedFileName.bold)")

      var printer = CodePrinter()
      printer.print("// Empty file generated on purpose")
      _ = try printer.writeContents(
        outputDirectory: self.swiftOutputDirectory,
        javaPackagePath: nil,
        filename: expectedFileName,
      )
    }
  }

  package func writeSwiftThunkSources(_ printer: inout CodePrinter) throws {
    let moduleFilenameBase = "\(self.swiftModuleName)Module+SwiftJava"
    let moduleFilename = "\(moduleFilenameBase).swift"

    do {
      // Skip the module-level .swift file when generating for a single type
      if config.singleType == nil {
        logger.trace("Printing swift module class: \(moduleFilename)")

        try printGlobalSwiftThunkSources(&printer)

        if let outputFile = try printer.writeContents(
          outputDirectory: self.swiftOutputDirectory,
          javaPackagePath: nil,
          filename: moduleFilename,
        ) {
          logger.info("Generated: \(moduleFilenameBase.bold).swift (at \(outputFile.absoluteString))")
          self.expectedOutputSwiftFileNames.remove(moduleFilename)
        }
      }

      // === All types
      // We have to write all types to their corresponding output file that matches the file they were declared in,
      // because otherwise SwiftPM plugins will not pick up files apropriately -- we expect 1 output +SwiftJava.swift file for every input.

      let filteredTypes: [String: ImportedNominalType]
      if let singleType = config.singleType {
        filteredTypes = self.analysis.importedTypes.filter { $0.key == singleType }
      } else {
        filteredTypes = self.analysis.importedTypes
      }

      for group: (key: String, value: [Dictionary<String, ImportedNominalType>.Element]) in Dictionary(
        grouping: filteredTypes,
        by: { $0.value.sourceFilePath },
      ) {
        logger.warning("Writing types in file group: \(group.key): \(group.value.map(\.key))")

        let importedTypesForThisFile = group.value
          .map(\.value)
          .sorted(by: { $0.qualifiedName < $1.qualifiedName })

        let inputFileName = "\(group.key)".split(separator: "/").last ?? "__Unknown.swift"
        let filename = "\(inputFileName)".replacing(/\.swift(interface)?/, with: "+SwiftJava.swift")

        for ty in importedTypesForThisFile {
          logger.info("Printing Swift thunks for type: \(ty.effectiveJavaName.bold)")
          printer.printSeparator("Thunks for \(ty.effectiveJavaName)")

          do {
            try printNominalTypeThunks(&printer, ty)
          } catch {
            logger.warning(
              "Failed to print to Swift thunks for type'\(ty.effectiveJavaName)' to '\(filename)', error: \(error)"
            )
          }

        }

        logger.warning("Write Swift thunks file: \(filename.bold)")
        do {
          if let outputFile = try printer.writeContents(
            outputDirectory: self.swiftOutputDirectory,
            javaPackagePath: nil,
            filename: filename,
          ) {
            logger.info("Done writing Swift thunks to: \(outputFile.absoluteString)")
            self.expectedOutputSwiftFileNames.remove(filename)
          }
        } catch {
          logger.warning("Failed to write to Swift thunks: \(filename), error: \(error)")
        }
      }
    } catch {
      logger.warning("Failed to write to Swift thunks: \(moduleFilename)")
    }
  }

  /// Writes a linker version script to the path specified by
  /// ``Configuration/linkerExportListOutput``, listing every JNI ``@_cdecl``
  /// symbol generated during this run as global exports and hiding everything
  /// else with `local: *`.
  ///
  /// Pass the resulting file to the linker with:
  /// ```
  /// -Xlinker --version-script=<path>
  /// ```
  /// This lets lld treat only the JNI entry points as roots during link-time
  /// dead-code elimination and hides all internal Swift symbols from the
  /// dynamic symbol table, removing unreachable Swift code from SPM
  /// dependencies and the Swift standard library.
  func writeLinkerExportList() throws {
    guard let outputPath = config.linkerExportListOutput else {
      return
    }
    guard !generatedCDeclSymbolNames.isEmpty else {
      return
    }

    let symbolLines =
      generatedCDeclSymbolNames
      .sorted()
      .map { "  \($0);" }
      .joined(separator: "\n")
    let contents =
      """
      {
        global:
        \(symbolLines)
        local: *;
      };
      """

    try contents.write(
      toFile: outputPath,
      atomically: true,
      encoding: .utf8,
    )
    logger.info("[swift-java] Generated linker export list (\(generatedCDeclSymbolNames.count) symbols): \(outputPath)")
  }

  private func printJNICache(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    let targetCases = type.cases
      .compactMap(translatedEnumCase(for:))
      .filter { !$0.translatedValues.isEmpty }
    if targetCases.isEmpty {
      return
    }

    printer.printBraceBlock("enum \(JNICaching.cacheName(for: type))") { printer in
      for translatedCase in targetCases {
        printer.print(
          "static let \(JNICaching.cacheMemberName(for: translatedCase)) = \(renderEnumCaseCacheInit(translatedCase))"
        )
      }
    }
  }

  /// Prints the extension needed to make allow upcalls from Swift to Java for protocols
  private func printSwiftInterfaceWrapper(
    _ printer: inout CodePrinter,
    _ translatedWrapper: JavaInterfaceSwiftWrapper,
  ) throws {
    printer.printBraceBlock("protocol \(translatedWrapper.wrapperName): \(translatedWrapper.swiftName)") { printer in
      printer.print(
        "var \(translatedWrapper.javaInterfaceVariableName): \(translatedWrapper.javaInterfaceName) { get }"
      )
    }
    printer.println()
    try printer.printBraceBlock("extension \(translatedWrapper.wrapperName)") { printer in
      for function in translatedWrapper.functions {
        try printInterfaceWrapperFunctionImpl(&printer, function, inside: translatedWrapper)
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
    inside wrapper: JavaInterfaceSwiftWrapper,
  ) throws {
    guard
      let protocolMethod = wrapper.importedType.methods.first(where: {
        $0.functionSignature == function.originalFunctionSignature
      })
    else {
      fatalError("Failed to find protocol method")
    }
    guard let translatedDecl = self.translatedDecl(for: protocolMethod) else {
      throw JavaTranslationError.protocolWasNotExtracted
    }

    printer.printBraceBlock(function.swiftDecl.signatureString) { printer in
      let resultType = function.originalFunctionSignature.result.type
      let returnStmt = !resultType.isVoid ? "return " : ""
      // If the protocol function is non-throwing, we have no option but to force try.
      // The error thrown by `withLocalFrame` is an OOM error anyway.
      let withLocalFrameTryKeyword = function.originalFunctionSignature.isThrowing ? "try" : "try!"

      // Push a local JNI frame so refs created during this upcall are freed on exit.
      // When called from a Swift async context (e.g. cooperative thread pool) there is
      // no enclosing JNI frame, so refs would otherwise accumulate indefinitely. When
      // called from a Java-initiated native call there is already a frame, but pushing
      // a sub-frame still frees refs earlier and prevents overflow within a single call.
      let paramCount = function.originalFunctionSignature.parameters.count
      let estimatedRefCount = paramCount * 2 + 4
      printer.print("let environment$ = try! JavaVirtualMachine.shared().environment()")
      printer.printBraceBlock("\(returnStmt)\(withLocalFrameTryKeyword) environment$.withLocalFrame(capacity: \(estimatedRefCount))") { printer in
        var upcallArguments = zip(
          function.originalFunctionSignature.parameters,
          function.parameterConversions,
        ).map { param, conversion in
          // Wrap-java does not extract parameter names, so no labels
          conversion.render(&printer, param.parameterName!)
        }

        // If the underlying translated method requires
        // a SwiftArena, we pass in the global arena
        if translatedDecl.translatedFunctionSignature.requiresSwiftArena {
          upcallArguments.append("JavaSwiftArena.defaultAutoArena")
        }

        let tryClause = function.originalFunctionSignature.isThrowing ? "try " : ""
        let javaUpcall =
          "\(tryClause)\(wrapper.javaInterfaceVariableName).\(function.swiftFunctionName)(\(upcallArguments.joined(separator: ", ")))"

        let result = function.resultConversion.render(&printer, javaUpcall)
        printer.print("\(returnStmt)\(result)")
      }
    }
  }

  private func printerInterfaceWrapperVariable(
    _ printer: inout CodePrinter,
    _ variable: JavaInterfaceSwiftWrapper.Variable,
    inside wrapper: JavaInterfaceSwiftWrapper,
  ) {
    // FIXME: Add support for variables. This won't get printed yet
    // so we no need to worry about fatalErrors.
    printer.printBraceBlock(variable.swiftDecl.signatureString) { printer in
      printer.printBraceBlock("get") { printer in
        printer.print("fatalError()")
      }

      if variable.setter != nil {
        printer.printBraceBlock("set") { printer in
          printer.print("fatalError()")
        }
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
      try printProtocolThunks(&printer, type)
    }
  }

  private func printConcreteTypeThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    let savedPrintingTypeName = self.currentPrintingTypeName
    let savedPrintingType = self.currentPrintingType
    self.currentPrintingTypeName = type.effectiveJavaTypeName
    self.currentPrintingType = type
    defer {
      self.currentPrintingTypeName = savedPrintingTypeName
      self.currentPrintingType = savedPrintingType
    }

    // Specialized types are treated as concrete even if the underlying Swift type is generic
    let isEffectivelyGeneric = type.swiftNominal.isGeneric && !type.isSpecialization

    if isEffectivelyGeneric {
      printOpenerProtocol(&printer, type)
      printer.println()
    }

    for initializer in type.initializers {
      printSwiftFunctionThunk(&printer, initializer)
      printer.println()
    }

    if type.swiftNominal.kind == .enum {
      printEnumRawDiscriminator(&printer, type)
      printer.println()

      if !isEffectivelyGeneric {
        for enumCase in type.cases {
          printEnumCase(&printer, enumCase)
          printer.println()
        }
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

    printSpecificTypeThunks(&printer, type)
    printTypeMetadataAddressThunk(&printer, type)
    printer.println()
  }

  private func printProtocolThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) throws {
    guard let protocolWrapper = self.interfaceProtocolWrappers[type] else {
      return
    }

    try printSwiftInterfaceWrapper(&printer, protocolWrapper)
  }

  private func printEnumRawDiscriminator(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    if type.cases.isEmpty {
      return
    }

    printer.printBraceBlock("extension \(type.effectiveSwiftTypeName): _RawDiscriminatorRepresentable") { printer in
      printer.printBraceBlock("public var _rawDiscriminator: Int32") { printer in
        printer.printBraceBlock("switch self") { printer in
          for (idx, enumCase) in type.cases.enumerated() {
            printer.print("case .\(enumCase.name): return \(idx)")
          }
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
    let methodSignature = MethodSignature(
      resultType: .void,
      parameterTypes: enumCase.parameterConversions.map(\.native.javaType),
    )

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
    _ enumCase: TranslatedEnumCase,
  ) {
    printCDecl(
      &printer,
      enumCase.getAsCaseFunction,
    ) { printer in
      let selfPointer = enumCase.getAsCaseFunction.nativeFunctionSignature.selfParameter!.conversion.render(
        &printer,
        "selfPointer",
      )
      let caseNames = enumCase.original.parameters.enumerated().map { idx, parameter in
        parameter.name ?? "_\(idx)"
      }
      let caseNamesWithLet = caseNames.map { "let \($0)" }
      let methodSignature = MethodSignature(
        resultType: .void,
        parameterTypes: enumCase.parameterConversions.map(\.native.javaType),
      )
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
    _ decl: ImportedFunc,
  ) {
    guard let translatedDecl = translatedDecl(for: decl) else {
      // Failed to translate. Skip.
      return
    }

    printSwiftFunctionHelperClasses(&printer, decl)

    printCDecl(
      &printer,
      translatedDecl,
    ) { printer in
      if let parent = decl.parentType?.asNominalType, parent.nominalTypeDecl.isGeneric {
        if self.currentPrintingType?.isSpecialization == true {
          // Specializations use direct calls with concrete type, not protocol opening
          self.printFunctionDowncall(&printer, decl)
        } else {
          self.printFunctionOpenerCall(&printer, decl)
        }
      } else {
        self.printFunctionDowncall(&printer, decl)
      }
    }
  }

  private func printSwiftFunctionHelperClasses(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
  ) {
    let protocolParameters = decl.functionSignature.parameters.compactMap { parameter in
      if let concreteType = parameter.type.typeIn(
        genericParameters: decl.functionSignature.genericParameters,
        genericRequirements: decl.functionSignature.genericRequirements,
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
        parentName: decl.parentType?.asNominalType?.nominalTypeDecl.qualifiedTypeName ?? SwiftQualifiedTypeName(swiftModuleName),
      )
      let implementingProtocols = protocolWrappers.map(\.wrapperName).joined(separator: ", ")

      printer.printBraceBlock("final class \(swiftClassName): \(implementingProtocols)") { printer in
        let variables: [(String, String)] = protocolWrappers.map { wrapper in
          (wrapper.javaInterfaceVariableName, wrapper.javaInterfaceName)
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
    self.analysis.importedTypes.first(
      where: ({ name, nominalType in
        nominalType.swiftType == type
      })
    ).map {
      $0.value
    }
  }

  private func printFunctionDowncall(
    _ printer: inout CodePrinter,
    _ decl: ImportedFunc,
  ) {
    guard let translatedDecl = self.translatedDecl(for: decl) else {
      fatalError("Cannot print function downcall for a function that can't be translated: \(decl)")
    }
    let nativeSignature = translatedDecl.nativeFunctionSignature

    let tryClause: String = decl.isThrowing ? "try " : ""

    // Regular parameters.
    var arguments: [String] = [String]()
    var indirectVariables: [(name: String, lowered: String)] = []
    var int32OverflowChecks: [String] = []

    for (idx, parameter) in nativeSignature.parameters.enumerated() {
      let javaParameterName = translatedDecl.translatedFunctionSignature.parameters[idx].parameter.name
      let lowered = parameter.conversion.render(&printer, javaParameterName)
      arguments.append(lowered)

      parameter.indirectConversion.flatMap {
        indirectVariables.append((javaParameterName, $0.render(&printer, javaParameterName)))
      }

      switch parameter.conversionCheck {
      case .check32BitIntOverflow:
        int32OverflowChecks.append(
          parameter.conversionCheck!.render(
            &printer,
            JNISwift2JavaGenerator.indirectVariableName(for: javaParameterName),
          )
        )
      case nil:
        break
      }
    }

    // Make indirect variables
    for (name, lowered) in indirectVariables {
      printer.print("let \(JNISwift2JavaGenerator.indirectVariableName(for: name)) = \(lowered)")
    }

    if !int32OverflowChecks.isEmpty {
      printer.print("#if _pointerBitWidth(_32)")

      for check in int32OverflowChecks {
        printer.printBraceBlock("guard \(check) else") { printer in
          printer.print("environment.throwJavaException(javaException: .integerOverflow)")
          printer.print(dummyReturn(for: nativeSignature))
        }
      }
      printer.print("#endif")
    }

    // Callee
    let callee: String =
      switch decl.functionSignature.selfParameter {
      case .instance:
        if let specializedType = self.currentPrintingType, specializedType.isSpecialization {
          // For specializations, use the concrete Swift type for pointer casting
          // (the cached conversion uses the raw generic type name which won't compile)
          self.renderSpecializedSelfPointer(
            &printer,
            concreteSwiftType: specializedType.effectiveSwiftTypeName,
          )
        } else {
          nativeSignature.selfParameter!.conversion.render(
            &printer,
            "selfPointer",
          )
        }
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
        arguments,
      ).map { originalParam, argument in
        let label = originalParam.argumentLabel.map { "\($0): " } ?? ""
        return "\(label)\(argument)"
      }
      .joined(separator: ", ")
      result = "\(tryClause)\(callee).\(decl.name)(\(downcallArguments))"

    case .enumCase:
      let downcallArguments = zip(
        decl.functionSignature.parameters,
        arguments,
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
      printer.print("do {")
      printer.indent()
      printer.print(innerBody(in: &printer))
      printer.outdent()
      printer.print("} catch {")
      printer.indent()
      printer.print(
        """
        environment.throwAsException(error)
        \(dummyReturn(for: nativeSignature))
        """
      )
      printer.outdent()
      printer.print("}")
    } else {
      printer.print(innerBody(in: &printer))
    }
  }

  private func dummyReturn(for nativeSignature: NativeFunctionSignature) -> String {
    if nativeSignature.result.javaType.isVoid {
      "return"
    } else if nativeSignature.result.javaType.isString {
      "return String.jniPlaceholderValue"
    } else {
      // We assume it is something that implements JavaValue
      "return \(nativeSignature.result.javaType.swiftTypeName(resolver: { _ in "" })).jniPlaceholderValue"
    }
  }

  private func printCDecl(
    _ printer: inout CodePrinter,
    _ translatedDecl: TranslatedFunctionDecl,
    _ body: (inout CodePrinter) -> Void,
  ) {
    let nativeSignature = translatedDecl.nativeFunctionSignature
    var parameters = nativeSignature.parameters.flatMap(\.parameters)

    if let selfParameter = nativeSignature.selfParameter {
      parameters += selfParameter.parameters
    }
    if let selfTypeParameter = nativeSignature.selfTypeParameter {
      parameters += selfTypeParameter.parameters
    }
    parameters += nativeSignature.result.outParameters

    printCDecl(
      &printer,
      javaMethodName: translatedDecl.nativeFunctionName,
      parentName: self.currentPrintingTypeName ?? translatedDecl.parentName,
      parameters: parameters,
      resultType: nativeSignature.result.javaType,
    ) { printer in
      body(&printer)
    }
  }

  private func printCDecl(
    _ printer: inout CodePrinter,
    javaMethodName: String,
    parentName: SwiftQualifiedTypeName,
    parameters: [JavaParameter],
    resultType: JavaType,
    _ body: (inout CodePrinter) -> Void,
  ) {
    let jniSignature = parameters.reduce(into: "") { signature, parameter in
      signature += parameter.type.jniTypeSignature
    }

    let cName =
      "Java_"
      + self.javaPackage.replacingOccurrences(of: ".", with: "_")
      + "_\(parentName.jniEscapedName.escapedJNIIdentifier)_"
      + javaMethodName.escapedJNIIdentifier
      + "__"
      + jniSignature.escapedJNIIdentifier

    self.generatedCDeclSymbolNames.append(cName)

    let translatedParameters = parameters.map {
      "\($0.name): \($0.type.jniTypeName)"
    }

    let thunkParameters =
      [
        "environment: UnsafeMutablePointer<JNIEnv?>!",
        "thisClass: jclass",
      ] + translatedParameters
    let thunkReturnType = resultType != .void ? " -> \(resultType.jniTypeName)" : ""

    // TODO: Think about function overloads
    printer.printBraceBlock(
      """
      #if compiler(>=6.3)
      @used
      #endif
      @_cdecl("\(cName)")
      public func \(cName)(\(thunkParameters.joined(separator: ", ")))\(thunkReturnType)
      """
    ) { printer in
      body(&printer)
    }
  }

  private func printHeader(_ printer: inout CodePrinter) {
    // `public import` so the thunk file remains valid under
    // `InternalImportsByDefault` (SE-0409)
    printer.print(
      """
      // Generated by swift-java

      public import SwiftJava
      public import SwiftJavaJNICore
      public import SwiftJavaRuntimeSupport

      """
    )

    self.lookupContext.symbolTable.printImportedModules(&printer)
  }

  private func printTypeMetadataAddressThunk(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    // Specialized types are treated as concrete
    let isEffectivelyGeneric = type.swiftNominal.isGeneric && !type.isSpecialization
    if isEffectivelyGeneric {
      return
    }

    printCDecl(
      &printer,
      javaMethodName: "$typeMetadataAddressDowncall",
      parentName: type.effectiveJavaTypeName,
      parameters: [],
      resultType: .long,
    ) { printer in
      printer.print(
        """
        let metadataPointer = unsafeBitCast(\(type.effectiveSwiftTypeName).self, to: UnsafeRawPointer.self)
        return Int64(Int(bitPattern: metadataPointer)).getJNIValue(in: environment)
        """
      )
    }
  }

  /// Prints thunks for specific known types like Foundation.Date, Foundation.Data
  private func printSpecificTypeThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    guard let knownType = type.swiftNominal.knownTypeKind else { return }

    switch knownType {
    case .foundationData, .essentialsData:
      printFoundationDataThunks(&printer, type)
      printer.println()

    default:
      break
    }
  }

  /// Prints Swift thunks for Foundation.Data helper methods
  private func printFoundationDataThunks(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    let selfPointerParam = JavaParameter(name: "selfPointer", type: .long)
    let parentName = type.qualifiedName

    // Rebind the memory instead of converting, and set the memory directly using 'jniSetArrayRegion' from the buffer
    printCDecl(
      &printer,
      javaMethodName: "$toByteArray",
      parentName: type.effectiveJavaTypeName,
      parameters: [
        selfPointerParam
      ],
      resultType: .array(.byte),
    ) { printer in
      let selfVar = self.printSelfJLongToUnsafeMutablePointer(&printer, swiftParentName: parentName, selfPointerParam)

      printer.print(
        """
        return \(selfVar).pointee.withUnsafeBytes { buffer in
          return buffer.getJNIValue(in: environment)
        }
        """
      )
    }

    // Legacy API, also to compare with as a baseline, we could remove it
    printCDecl(
      &printer,
      javaMethodName: "$toByteArrayIndirectCopy",
      parentName: type.effectiveJavaTypeName,
      parameters: [
        selfPointerParam
      ],
      resultType: .array(.byte),
    ) { printer in
      let selfVar = self.printSelfJLongToUnsafeMutablePointer(&printer, swiftParentName: parentName, selfPointerParam)

      printer.print(
        """
        // This is a double copy, we need to initialize the array and then copy into a JVM array in getJNIValue
        return [UInt8](\(selfVar).pointee).getJNIValue(in: environment)
        """
      )
    }
  }

  private func printFunctionOpenerCall(_ printer: inout CodePrinter, _ decl: ImportedFunc) {
    guard let translatedDecl = self.translatedDecl(for: decl) else {
      fatalError("Cannot print function opener for a function that can't be translated: \(decl)")
    }
    guard let parentNominalType = decl.parentType?.asNominalType else {
      fatalError("Only functions with nominal type parents can have openers")
    }
    let nativeSignature = translatedDecl.nativeFunctionSignature

    let selfType = nativeSignature.selfTypeParameter!.conversion.render(&printer, "selfTypePointer")
    let openerName = openerProtocolName(for: parentNominalType.nominalTypeDecl)
    printer.print("let openerType = \(selfType) as! (any \(openerName).Type)")

    var parameters = nativeSignature.parameters.flatMap(\.parameters)
    if let selfParameter = nativeSignature.selfParameter {
      parameters += selfParameter.parameters
    }
    parameters += nativeSignature.result.outParameters

    let openerArguments =
      [
        "environment: environment",
        "thisClass: thisClass",
      ]
      + parameters.map { javaParameter in
        "\(javaParameter.name): \(javaParameter.name)"
      }
    let call = "openerType.\(decl.openerMethodName)(\(openerArguments.joined(separator: ", ")))"

    if !decl.functionSignature.result.type.isVoid {
      printer.print("return \(call)")
    } else {
      printer.print(call)
    }
  }

  private func openerProtocolName(for type: SwiftNominalTypeDeclaration) -> String {
    "_\(swiftModuleName)_\(type.name)_opener"
  }

  private func printOpenerProtocol(_ printer: inout CodePrinter, _ type: ImportedNominalType) {
    let protocolName = openerProtocolName(for: type.swiftNominal)

    func printFunctionDecl(_ printer: inout CodePrinter, decl: ImportedFunc, skipMethodBody: Bool) {
      guard let translatedDecl = self.translatedDecl(for: decl) else { return }
      let nativeSignature = translatedDecl.nativeFunctionSignature

      var parameters = nativeSignature.parameters.flatMap(\.parameters)
      if let selfParameter = nativeSignature.selfParameter {
        parameters += selfParameter.parameters
      }
      parameters += nativeSignature.result.outParameters

      let resultType = nativeSignature.result.javaType

      let translatedParameters = parameters.map {
        "\($0.name): \($0.type.jniTypeName)"
      }

      let thunkParameters =
        [
          "environment: UnsafeMutablePointer<JNIEnv?>!",
          "thisClass: jclass",
        ] + translatedParameters
      let thunkReturnType = resultType != .void ? " -> \(resultType.jniTypeName)" : ""

      let signature = #"static func \#(decl.openerMethodName)(\#(thunkParameters.joined(separator: ", ")))\#(thunkReturnType)"#
      if !skipMethodBody {
        printer.printBraceBlock(signature) { printer in
          printFunctionDowncall(&printer, decl)
        }
      } else {
        printer.print(signature)
      }
    }

    printer.printBraceBlock("protocol \(protocolName)") { printer in
      for variable in type.variables {
        printFunctionDecl(&printer, decl: variable, skipMethodBody: true)
      }

      for method in type.methods {
        printFunctionDecl(&printer, decl: method, skipMethodBody: true)
      }
    }
    printer.println()
    printer.printBraceBlock("extension \(type.swiftNominal.name): \(protocolName)") { printer in
      for variable in type.variables {
        if variable.isStatic { continue }
        printFunctionDecl(&printer, decl: variable, skipMethodBody: false)
      }

      for method in type.methods {
        if method.isStatic { continue }
        printFunctionDecl(&printer, decl: method, skipMethodBody: false)
      }
    }
  }

  /// Renders self pointer extraction for a specialized (concrete) type.
  /// Used instead of the generic opener mechanism when we know the exact type at compile time.
  ///
  /// - Returns: name of the created "self" variable (e.g., "selfPointer$")
  private func renderSpecializedSelfPointer(
    _ printer: inout CodePrinter,
    concreteSwiftType: String,
  ) -> String {
    printer.print(
      """
      assert(selfPointer != 0, "selfPointer memory address was null")
      let selfPointerBits$ = Int(Int64(fromJNI: selfPointer, in: environment))
      let selfPointer$ = UnsafeMutablePointer<\(concreteSwiftType)>(bitPattern: selfPointerBits$)
      guard let selfPointer$ else {
        fatalError("selfPointer memory address was null in call to \\(#function)!")
      }
      """
    )
    return "selfPointer$.pointee"
  }

  /// Print the necessary conversion logic to go from a `jlong` to a `UnsafeMutablePointer<Type>`
  ///
  /// - Returns: name of the created "self" variable
  private func printSelfJLongToUnsafeMutablePointer(
    _ printer: inout CodePrinter,
    swiftParentName: String,
    _ selfPointerParam: JavaParameter,
  ) -> String {
    let newSelfParamName = "selfPointer$"
    printer.print(
      """
      guard let env$ = environment else {
        fatalError("Missing JNIEnv in downcall to \\(#function)")
      }
      assert(\(selfPointerParam.name) != 0, "\(selfPointerParam.name) memory address was null")
      let selfPointerBits$ = Int(Int64(fromJNI: \(selfPointerParam.name), in: env$))
      guard let \(newSelfParamName) = UnsafeMutablePointer<\(swiftParentName)>(bitPattern: selfPointerBits$) else {
        fatalError("selfPointer memory address was null in call to \\(#function)!")
      }
      """
    )
    return newSelfParamName
  }

  static func protocolParameterWrapperClassName(
    methodName: String,
    parameterName: String,
    parentName: SwiftQualifiedTypeName?,
  ) -> String {
    let parent =
      if let parentName {
        "\(parentName.fullFlatName)_"
      } else {
        ""
      }
    return "_\(parent)\(methodName)_\(parameterName)_Wrapper"
  }
}

extension SwiftNominalTypeDeclaration {
  private var safeProtocolName: String {
    self.flatName
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

extension ImportedFunc {
  fileprivate var openerMethodName: String {
    let prefix =
      switch apiKind {
      case .getter: "_get_"
      case .setter: "_set_"
      default: "_"
      }
    return "\(prefix)\(name)"
  }
}
