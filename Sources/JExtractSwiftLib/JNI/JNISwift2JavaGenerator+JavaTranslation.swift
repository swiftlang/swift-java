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

import CodePrinting
import SwiftJavaConfigurationShared
import SwiftJavaJNICore

extension JNISwift2JavaGenerator {
  var javaTranslator: JavaTranslation {
    JavaTranslation(
      config: config,
      swiftModuleName: swiftModuleName,
      javaPackage: self.javaPackage,
      javaClassLookupTable: self.javaClassLookupTable,
      dependentJavaPackages: self.dependentJavaPackages,
      knownTypes: SwiftKnownTypes(symbolTable: lookupContext.symbolTable),
      protocolWrappers: self.interfaceProtocolWrappers,
      logger: self.logger,
      javaIdentifiers: self.currentJavaIdentifiers,
      importedTypes: self.analysis.importedTypes,
    )
  }

  func translatedDecl(
    for decl: ImportedFunc
  ) -> TranslatedFunctionDecl? {
    if let cached = translatedDecls[decl] {
      return cached
    }

    let translated: TranslatedFunctionDecl?
    do {
      translated = try self.javaTranslator.translate(decl)
    } catch {
      self.logger.debug("Failed to translate: '\(decl.swiftDecl.qualifiedNameForDebug)'; \(error)")
      translated = nil
    }

    translatedDecls[decl] = translated
    return translated
  }

  func translatedEnumCase(
    for decl: ImportedEnumCase
  ) -> TranslatedEnumCase? {
    if let cached = translatedEnumCases[decl] {
      return cached
    }

    let translated: TranslatedEnumCase?
    do {
      let translation = JavaTranslation(
        config: config,
        swiftModuleName: swiftModuleName,
        javaPackage: self.javaPackage,
        javaClassLookupTable: self.javaClassLookupTable,
        dependentJavaPackages: self.dependentJavaPackages,
        knownTypes: SwiftKnownTypes(symbolTable: lookupContext.symbolTable),
        protocolWrappers: self.interfaceProtocolWrappers,
        logger: self.logger,
        javaIdentifiers: self.currentJavaIdentifiers,
        importedTypes: self.analysis.importedTypes,
      )
      translated = try translation.translate(enumCase: decl)
    } catch {
      self.logger.debug("Failed to translate: '\(decl.swiftDecl.qualifiedNameForDebug)'; \(error)")
      translated = nil
    }

    translatedEnumCases[decl] = translated
    return translated
  }

  struct JavaTranslation {
    let config: Configuration
    let swiftModuleName: String
    let javaPackage: String
    let javaClassLookupTable: JavaClassLookupTable
    let dependentJavaPackages: [String: String]
    var knownTypes: SwiftKnownTypes
    let protocolWrappers: [ImportedNominalType: JavaInterfaceSwiftWrapper]
    let logger: Logger
    var javaIdentifiers: JavaIdentifierFactory
    let importedTypes: [String: ImportedNominalType]

    func translate(enumCase: ImportedEnumCase) throws -> TranslatedEnumCase {
      let nativeTranslation = NativeJavaTranslation(
        config: self.config,
        javaPackage: self.javaPackage,
        javaClassLookupTable: self.javaClassLookupTable,
        knownTypes: self.knownTypes,
        protocolWrappers: self.protocolWrappers,
        logger: self.logger,
      )

      let methodName = "" // TODO: Used for closures, replace with better name?
      let parentName = SwiftQualifiedTypeName("") // TODO: Used for closures, replace with better name?

      let translatedValues = try self.translateParameters(
        enumCase.parameters.map { ($0.name, $0.type) },
        methodName: methodName,
        parentName: parentName,
        genericParameters: [],
        genericRequirements: [],
      )

      let conversions = try enumCase.parameters.enumerated().map { idx, parameter in
        let resultName = parameter.name ?? "arg\(idx)"
        let result = SwiftResult(convention: .direct, type: parameter.type)
        var translatedResult = try self.translate(swiftResult: result, methodName: methodName, resultName: resultName)
        translatedResult.conversion = .replacingPlaceholder(
          translatedResult.conversion,
          placeholder: "$nativeParameters.\(resultName)",
        )
        let nativeResult = try nativeTranslation.translate(swiftResult: result, methodName: methodName, resultName: resultName)
        return (translated: translatedResult, native: nativeResult)
      }

      let caseName = enumCase.name.firstCharacterUppercased
      let enumName = enumCase.enumType.nominalTypeDecl.name
      let nativeParametersType = JavaType.class(package: nil, name: "\(caseName)._NativeParameters")
      let getAsCaseName = "getAs\(caseName)"
      // If the case has no parameters, we can skip the native call.
      let constructRecordConversion = JavaNativeConversionStep.method(
        .constant("Optional"),
        function: "of",
        arguments: [
          .constructJavaClass(
            .commaSeparated(conversions.map(\.translated.conversion)),
            .class(package: nil, name: caseName),
          )
        ],
      )
      var exceptions: [JavaExceptionType] = []

      if enumCase.parameters.contains(where: \.type.isArchDependingInteger) {
        exceptions.append(.integerOverflow)
      }

      let isGenericParent = enumCase.caseFunction.parentType?.asNominalTypeDeclaration?.isGeneric == true

      let getAsCaseFunction = TranslatedFunctionDecl(
        name: getAsCaseName,
        isStatic: false,
        isThrowing: false,
        isAsync: false,
        nativeFunctionName: "$\(getAsCaseName)",
        parentName: SwiftQualifiedTypeName(enumName),
        functionTypes: [],
        translatedFunctionSignature: TranslatedFunctionSignature(
          selfParameter: TranslatedParameter(
            parameter: JavaParameter(name: "selfPointer", type: .long),
            conversion: .aggregate(
              [
                .ifStatement(
                  .constant("getDiscriminator() != Discriminator.\(caseName.uppercased())"),
                  thenExp: .constant("return Optional.empty();"),
                ),
                .valueMemoryAddress(.placeholder),
              ]
            ),
          ),
          selfTypeParameter: !isGenericParent
            ? nil
            : .init(
              parameter: JavaParameter(name: "selfTypePointer", type: .long),
              conversion: .typeMetadataAddress(.placeholder),
            ),
          parameters: [],
          resultType: TranslatedResult(
            javaType: .class(package: nil, name: "Optional", typeParameters: [.class(package: nil, name: caseName)]),
            outParameters: conversions.flatMap(\.translated.outParameters),
            conversion: enumCase.parameters.isEmpty
              ? constructRecordConversion
              : .aggregate(variable: ("$nativeParameters", nativeParametersType), [constructRecordConversion]),
          ),
          exceptions: exceptions,
        ),
        nativeFunctionSignature: NativeFunctionSignature(
          selfParameter: NativeParameter(
            parameters: [JavaParameter(name: "selfPointer", type: .long)],
            conversion: .extractSwiftValue(.placeholder, swiftType: .nominal(enumCase.enumType), allowNil: false),
            indirectConversion: nil,
            conversionCheck: nil,
          ),
          selfTypeParameter: !isGenericParent
            ? nil
            : .init(
              parameters: [JavaParameter(name: "selfTypePointer", type: .long)],
              conversion: .extractMetatypeValue(.placeholder),
              indirectConversion: nil,
              conversionCheck: nil,
            ),
          parameters: [],
          result: NativeResult(
            javaType: nativeParametersType,
            conversion: .placeholder,
            outParameters: conversions.flatMap(\.native.outParameters),
          ),
        ),
      )

      return TranslatedEnumCase(
        name: enumCase.name.firstCharacterUppercased,
        enumName: enumCase.enumType.nominalTypeDecl.name,
        original: enumCase,
        translatedValues: translatedValues,
        parameterConversions: conversions,
        getAsCaseFunction: getAsCaseFunction,
      )
    }

    func translate(_ decl: ImportedFunc) throws -> TranslatedFunctionDecl {
      let nativeTranslation = NativeJavaTranslation(
        config: self.config,
        javaPackage: self.javaPackage,
        javaClassLookupTable: self.javaClassLookupTable,
        knownTypes: self.knownTypes,
        protocolWrappers: self.protocolWrappers,
        logger: self.logger,
      )

      // Types with no parent will be outputted inside a "module" class.
      // For specialized types, use the Java-facing name as the parent scope
      let parentName: SwiftQualifiedTypeName
      if let parentNominal = decl.parentType?.asNominalType?.nominalTypeDecl {
        let importedParent = importedTypes.values.first { $0.swiftNominal === parentNominal }
        parentName = importedParent?.effectiveJavaTypeName ?? parentNominal.qualifiedTypeName
      } else {
        parentName = SwiftQualifiedTypeName(swiftModuleName)
      }

      // Name.
      let javaName = javaIdentifiers.makeJavaMethodName(decl)

      // Swift -> Java
      var translatedFunctionSignature = try self.translate(
        functionSignature: decl.functionSignature,
        methodName: javaName,
        parentName: parentName,
      )
      // Java -> Java (native)
      var nativeFunctionSignature = try nativeTranslation.translate(
        functionSignature: decl.functionSignature,
        translatedFunctionSignature: translatedFunctionSignature,
        methodName: javaName,
        parentName: parentName,
      )

      // Closures.
      var funcTypes: [TranslatedFunctionType] = []
      for (idx, param) in decl.functionSignature.parameters.enumerated() {
        let parameterName = param.parameterName ?? "_\(idx)"

        switch param.type {
        case .function(let funcTy):
          let translatedClosure = try translateFunctionType(
            name: parameterName,
            swiftType: funcTy,
            parentName: parentName,
          )
          funcTypes.append(translatedClosure)
        default:
          break
        }
      }

      // Handle async methods
      if decl.functionSignature.isAsync {
        self.convertToAsync(
          translatedFunctionSignature: &translatedFunctionSignature,
          nativeFunctionSignature: &nativeFunctionSignature,
          originalFunctionSignature: decl.functionSignature,
          mode: config.effectiveAsyncFuncMode,
        )
      }

      return TranslatedFunctionDecl(
        name: javaName,
        isStatic: decl.isStatic || !decl.hasParent || decl.isInitializer,
        isThrowing: decl.isThrowing,
        isAsync: decl.isAsync,
        nativeFunctionName: "$\(javaName)",
        parentName: parentName,
        functionTypes: funcTypes,
        translatedFunctionSignature: translatedFunctionSignature,
        nativeFunctionSignature: nativeFunctionSignature,
      )
    }

    /// Translate Swift closure type to Java functional interface.
    func translateFunctionType(
      name: String,
      swiftType: SwiftFunctionType,
      parentName: SwiftQualifiedTypeName,
    ) throws -> TranslatedFunctionType {
      var translatedParams: [TranslatedParameter] = []

      for (i, param) in swiftType.parameters.enumerated() {
        let paramName = param.parameterName ?? "_\(i)"
        translatedParams.append(
          try translateParameter(
            swiftType: param.type,
            parameterName: paramName,
            methodName: name,
            parentName: parentName,
            genericParameters: [],
            genericRequirements: [],
            parameterPosition: nil,
          )
        )
      }

      let translatedResult = try translate(swiftResult: SwiftResult(convention: .direct, type: swiftType.resultType), methodName: name)

      return TranslatedFunctionType(
        name: name,
        parameters: translatedParams,
        result: translatedResult,
        swiftType: swiftType,
      )
    }

    func translate(
      functionSignature: SwiftFunctionSignature,
      methodName: String,
      parentName: SwiftQualifiedTypeName,
    ) throws -> TranslatedFunctionSignature {
      let parameters = try translateParameters(
        functionSignature.parameters.map { ($0.parameterName, $0.type) },
        methodName: methodName,
        parentName: parentName,
        genericParameters: functionSignature.genericParameters,
        genericRequirements: functionSignature.genericRequirements,
      )

      // 'self'
      let selfParameter = try self.translateSelfParameter(
        functionSignature.selfParameter,
        methodName: methodName,
        parentName: parentName,
        genericParameters: functionSignature.genericParameters,
        genericRequirements: functionSignature.genericRequirements,
      )

      let selfTypeParameter = try self.translateSelfTypeParameter(
        functionSignature.selfParameter,
        methodName: methodName,
        parentName: parentName,
        genericParameters: functionSignature.genericParameters,
        genericRequirements: functionSignature.genericRequirements,
      )

      var exceptions: [JavaExceptionType] = []

      if functionSignature.parameters.contains(where: \.type.isArchDependingInteger) {
        exceptions.append(.integerOverflow)
      }

      let resultType = try translate(
        swiftResult: functionSignature.result,
        methodName: methodName,
        genericParameters: functionSignature.genericParameters,
        genericRequirements: functionSignature.genericRequirements,
      )

      return TranslatedFunctionSignature(
        selfParameter: selfParameter,
        selfTypeParameter: selfTypeParameter,
        parameters: parameters,
        resultType: resultType,
        exceptions: exceptions,
      )
    }

    func translateParameters(
      _ parameters: [(name: String?, type: SwiftType)],
      methodName: String,
      parentName: SwiftQualifiedTypeName,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> [TranslatedParameter] {
      try parameters.enumerated().map { idx, param in
        let parameterName = param.name ?? "arg\(idx)"
        return try translateParameter(
          swiftType: param.type,
          parameterName: parameterName,
          methodName: methodName,
          parentName: parentName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
          parameterPosition: idx,
        )
      }
    }

    func translateSelfParameter(
      _ selfParameter: SwiftSelfParameter?,
      methodName: String,
      parentName: SwiftQualifiedTypeName,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedParameter? {
      // 'self'
      if case .instance(_, let swiftType) = selfParameter {
        return try self.translateParameter(
          swiftType: swiftType,
          parameterName: "selfPointer",
          methodName: methodName,
          parentName: parentName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
          parameterPosition: nil,
        )
      } else {
        return nil
      }
    }

    func translateSelfTypeParameter(
      _ selfParameter: SwiftSelfParameter?,
      methodName: String,
      parentName: SwiftQualifiedTypeName,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedParameter? {
      guard let selfParameter else {
        return nil
      }

      let isGeneric = selfParameter.selfType.asNominalTypeDeclaration?.isGeneric == true
      if isGeneric {
        return try self.translateParameter(
          swiftType: .metatype(selfParameter.selfType),
          parameterName: "selfTypePointer",
          methodName: methodName,
          parentName: parentName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
          parameterPosition: nil,
        )
      } else {
        return nil
      }
    }

    func translateParameter(
      swiftType: SwiftType,
      parameterName: String,
      methodName: String,
      parentName: SwiftQualifiedTypeName,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
      parameterPosition: Int?,
    ) throws -> TranslatedParameter {

      // If the result type should cause any annotations on the method, include them here.
      let parameterAnnotations: [JavaAnnotation] = getJavaTypeAnnotations(swiftType: swiftType, config: config)

      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.qualifiedName

        if let knownType = nominalType.asKnownType {
          switch knownType {
          case .optional(let wrapped):
            return try translateOptionalParameter(
              wrappedType: wrapped,
              parameterName: parameterName,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )

          case .array(let elementType):
            return try translateArrayParameter(
              elementType: elementType,
              parameterName: parameterName,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )

          case .dictionary(let keyType, let valueType):
            return try translateDictionaryParameter(
              keyType: keyType,
              valueType: valueType,
              parameterName: parameterName,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )

          case .set(let elementType):
            return try translateSetParameter(
              elementType: elementType,
              parameterName: parameterName,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )

          case .foundationDate, .essentialsDate:
            break // Handled as wrapped struct

          case .foundationData, .essentialsData:
            break // Handled as wrapped struct

          case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
            return TranslatedParameter(
              parameter: JavaParameter(name: parameterName, type: .array(.byte)),
              conversion: .placeholder
            )

          case .foundationUUID, .essentialsUUID:
            return TranslatedParameter(
              parameter: JavaParameter(name: parameterName, type: .javaUtilUUID),
              conversion: .method(.placeholder, function: "toString"),
            )

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType.kind, config: self.config) else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            return TranslatedParameter(
              parameter: JavaParameter(name: parameterName, type: javaType, annotations: parameterAnnotations),
              conversion: .placeholder,
            )
          }
        }

        if nominalType.isSwiftJavaWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromSwiftJavaName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftType)
          }

          return TranslatedParameter(
            parameter: JavaParameter(name: parameterName, type: javaType, annotations: parameterAnnotations),
            conversion: .placeholder,
          )
        }

        let javaType = JavaType.class(
          package: dependentJavaPackages[nominalType.nominalTypeDecl.moduleName],
          name: nominalTypeName,
          typeParameters: try nominalType.genericArguments?.map { swiftType in
            try translateGenericTypeParameter(
              swiftType,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )
          } ?? [],
        )

        // We assume this is a JExtract class.
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .concrete(javaType),
            annotations: parameterAnnotations,
          ),
          conversion: .valueMemoryAddress(.placeholder),
        )

      case .tuple([]):
        return TranslatedParameter(
          parameter: JavaParameter(name: parameterName, type: .void, annotations: parameterAnnotations),
          conversion: .placeholder,
        )

      case .function:
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .class(package: javaPackage, name: "\(parentName.fullName).\(methodName).\(parameterName)"),
            annotations: parameterAnnotations,
          ),
          conversion: .placeholder,
        )

      case .opaque(let proto), .existential(let proto):
        guard let parameterPosition else {
          fatalError("Cannot extract opaque or existential type that is not a parameter: \(proto)")
        }

        return try translateProtocolParameter(
          protocolType: proto,
          parameterName: parameterName,
          javaGenericName: "_T\(parameterPosition)",
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )

      case .genericParameter(let generic):
        if let concreteTy = swiftType.typeIn(
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        ) {
          return try translateProtocolParameter(
            protocolType: concreteTy,
            parameterName: parameterName,
            javaGenericName: generic.name,
            genericParameters: genericParameters,
            genericRequirements: genericRequirements,
          )
        }

        throw JavaTranslationError.unsupportedSwiftType(swiftType)

      case .metatype:
        return TranslatedParameter(
          parameter: JavaParameter(name: parameterName, type: .long),
          conversion: .typeMetadataAddress(.placeholder),
        )

      case .tuple(let elements) where !elements.isEmpty:
        return try translateTupleParameter(
          elements: elements,
          parameterName: parameterName,
          methodName: methodName,
          parentName: parentName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
          parameterPosition: parameterPosition,
        )

      case .tuple:
        throw JavaTranslationError.emptyTuple()
      case .composite:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func translateTupleParameter(
      elements: [SwiftTupleElement],
      parameterName: String,
      methodName: String,
      parentName: SwiftQualifiedTypeName,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
      parameterPosition: Int?,
    ) throws -> TranslatedParameter {
      var elementJavaTypes: [JavaType] = []

      // Generate a conversion that extracts each element from the Tuple
      var elementConversions: [JavaNativeConversionStep] = []
      for (idx, element) in elements.enumerated() {
        let elementTranslated = try translateParameter(
          swiftType: element.type,
          parameterName: "\(parameterName)_\(idx)",
          methodName: methodName,
          parentName: parentName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
          parameterPosition: parameterPosition,
        )

        // Extract the element from the tuple using .$N field access
        let extraction = JavaNativeConversionStep.replacingPlaceholder(
          elementTranslated.conversion,
          placeholder: "\(parameterName).$\(idx)",
        )
        elementConversions.append(extraction)
        elementJavaTypes.append(elementTranslated.parameter.type.javaType)
      }

      let javaType: JavaType = .tuple(elementTypes: elementJavaTypes)

      return TranslatedParameter(
        parameter: JavaParameter(
          name: parameterName,
          type: javaType,
        ),
        conversion: .commaSeparated(elementConversions),
      )
    }

    func convertToAsync(
      translatedFunctionSignature: inout TranslatedFunctionSignature,
      nativeFunctionSignature: inout NativeFunctionSignature,
      originalFunctionSignature: SwiftFunctionSignature,
      mode: JExtractAsyncFuncMode,
    ) {
      // Update translated function
      let nativeFutureType: JavaType
      let translatedFutureType: JavaType
      let completeMethodID: String
      let completeExceptionallyMethodID: String

      switch mode {
      case .completableFuture:
        nativeFutureType = .completableFuture(nativeFunctionSignature.result.javaType)
        translatedFutureType = .completableFuture(translatedFunctionSignature.resultType.javaType)
        completeMethodID = "_JNIMethodIDCache.CompletableFuture.complete"
        completeExceptionallyMethodID = "_JNIMethodIDCache.CompletableFuture.completeExceptionally"

      case .legacyFuture:
        nativeFutureType = .simpleCompletableFuture(nativeFunctionSignature.result.javaType)
        translatedFutureType = .future(translatedFunctionSignature.resultType.javaType)
        completeMethodID = "_JNIMethodIDCache.SimpleCompletableFuture.complete"
        completeExceptionallyMethodID = "_JNIMethodIDCache.SimpleCompletableFuture.completeExceptionally"
      }

      let futureOutParameter = OutParameter(
        name: "future$",
        type: nativeFutureType,
        allocation: .new,
      )

      let result = translatedFunctionSignature.resultType
      translatedFunctionSignature.resultType = TranslatedResult(
        javaType: translatedFutureType,
        annotations: result.annotations,
        outParameters: result.outParameters + [futureOutParameter],
        conversion: .method(
          .constant("future$"),
          function: "thenApply",
          arguments: [
            .lambda(
              args: ["futureResult$"],
              body: .replacingPlaceholder(result.conversion, placeholder: "futureResult$")
            )
          ]
        )
      )

      // Update native function
      nativeFunctionSignature.result.conversion = .asyncCompleteFuture(
        swiftFunctionResultType: originalFunctionSignature.result.type,
        nativeFunctionSignature: nativeFunctionSignature,
        isThrowing: originalFunctionSignature.isThrowing,
        completeMethodID: completeMethodID,
        completeExceptionallyMethodID: completeExceptionallyMethodID,
      )
      nativeFunctionSignature.result.javaType = .void
      nativeFunctionSignature.result.outParameters.append(.init(name: "result_future", type: nativeFutureType))
    }

    func translateProtocolParameter(
      protocolType: SwiftType,
      parameterName: String,
      javaGenericName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedParameter {
      switch protocolType {
      case .nominal:
        return try translateProtocolParameter(
          protocolTypes: [protocolType],
          parameterName: parameterName,
          javaGenericName: javaGenericName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )

      case .composite(let types):
        return try translateProtocolParameter(
          protocolTypes: types,
          parameterName: parameterName,
          javaGenericName: javaGenericName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(protocolType)
      }
    }

    private func translateProtocolParameter(
      protocolTypes: [SwiftType],
      parameterName: String,
      javaGenericName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedParameter {
      let javaProtocolTypes = try protocolTypes.map {
        try translateGenericTypeParameter(
          $0,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )
      }

      // We just pass down the jobject
      return TranslatedParameter(
        parameter: JavaParameter(
          name: parameterName,
          type: .generic(name: javaGenericName, extends: javaProtocolTypes),
          annotations: [],
        ),
        conversion: .placeholder,
      )
    }

    func translateOptionalParameter(
      wrappedType swiftType: SwiftType,
      parameterName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedParameter {
      let parameterAnnotations: [JavaAnnotation] = getJavaTypeAnnotations(swiftType: swiftType, config: config)

      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.qualifiedName

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .foundationDate, .essentialsDate:
            // Handled as wrapped struct
            break

          case .foundationData, .essentialsData:
            // Handled as wrapped struct
            break

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config) else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            guard let translatedClass = javaType.optionalType, let placeholderValue = javaType.optionalPlaceholderValue
            else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            return TranslatedParameter(
              parameter: JavaParameter(
                name: parameterName,
                type: JavaType(className: translatedClass),
                annotations: parameterAnnotations,
              ),
              conversion: .commaSeparated([
                .isOptionalPresent,
                .method(.placeholder, function: "orElse", arguments: [.constant(placeholderValue)]),
              ]),
            )
          }
        }

        if nominalType.isSwiftJavaWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromSwiftJavaName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftType)
          }

          return TranslatedParameter(
            parameter: JavaParameter(
              name: parameterName,
              type: .class(package: nil, name: "Optional<\(javaType)>"),
              annotations: parameterAnnotations,
            ),
            conversion: .method(
              .placeholder,
              function: "orElse",
              arguments: [.constant("null")],
            ),
          )
        }

        // Assume JExtract imported class
        let javaType = try translateGenericTypeParameter(
          swiftType,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .class(package: nil, name: "Optional", typeParameters: [javaType]),
            annotations: parameterAnnotations,
          ),
          conversion: .method(
            .method(.placeholder, function: "map", arguments: [.constant("\(javaType)::$memoryAddress")]),
            function: "orElse",
            arguments: [.constant("0L")],
          ),
        )
      default:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func translate(
      swiftResult: SwiftResult,
      methodName: String,
      resultName: String = "result",
      genericParameters: [SwiftGenericParameterDeclaration] = [],
      genericRequirements: [SwiftGenericRequirement] = [],
    ) throws -> TranslatedResult {
      let swiftType = swiftResult.type

      // If the result type should cause any annotations on the method, include them here.
      let resultAnnotations: [JavaAnnotation] = getJavaTypeAnnotations(swiftType: swiftType, config: config)

      switch swiftType {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }
            return try translateOptionalResult(
              wrappedType: genericArgs[0],
              resultName: resultName,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )

          case .array:
            guard let elementType = nominalType.genericArguments?.first else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }
            return try translateArrayResult(
              elementType: elementType,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )

          case .dictionary:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 2 else {
              throw JavaTranslationError.dictionaryRequiresKeyAndValueTypes(swiftType)
            }
            return try translateDictionaryResult(
              keyType: genericArgs[0],
              valueType: genericArgs[1],
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )

          case .set:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.setRequiresElementType(swiftType)
            }
            return try translateSetResult(
              elementType: genericArgs[0],
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )

          case .foundationDate, .essentialsDate:
            // Handled as wrapped struct
            break

          case .foundationData, .essentialsData:
            // Handled as wrapped struct
            break

          case .foundationUUID, .essentialsUUID:
            return TranslatedResult(
              javaType: .javaUtilUUID,
              outParameters: [],
              conversion: .method(
                .constant("java.util.UUID"),
                function: "fromString",
                arguments: [.placeholder],
              ),
            )

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config) else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            return TranslatedResult(
              javaType: javaType,
              annotations: resultAnnotations,
              outParameters: [],
              conversion: .placeholder,
            )
          }
        }

        if nominalType.isSwiftJavaWrapper {
          throw JavaTranslationError.unsupportedSwiftType(swiftType)
        }

        let javaType = JavaType.class(
          package: dependentJavaPackages[nominalType.nominalTypeDecl.moduleName],
          name: nominalType.nominalTypeDecl.qualifiedName,
          typeParameters: try nominalType.genericArguments?.map { swiftType in
            try translateGenericTypeParameter(
              swiftType,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )
          } ?? [],
        )

        // We assume this is a JExtract class.
        if nominalType.nominalTypeDecl.isGeneric {
          return TranslatedResult(
            javaType: javaType,
            annotations: resultAnnotations,
            outParameters: [.init(name: resultName, type: ._OutSwiftGenericInstance, allocation: .new)],
            conversion: .wrapMemoryAddressUnsafe(
              .commaSeparated([
                .member(.constant(resultName), field: "selfPointer"),
                .member(.constant(resultName), field: "selfTypePointer"),
              ]),
              javaType
            )
          )
        } else {
          return TranslatedResult(
            javaType: javaType,
            annotations: resultAnnotations,
            outParameters: [],
            conversion: .wrapMemoryAddressUnsafe(.placeholder, javaType),
          )
        }

      case .tuple([]):
        return TranslatedResult(javaType: .void, outParameters: [], conversion: .placeholder)

      case .tuple(let elements) where !elements.isEmpty:
        return try translateTupleResult(
          methodName: methodName,
          elements: elements,
          resultName: resultName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )

      case .metatype, .tuple, .function, .existential, .opaque, .genericParameter, .composite:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    private func translateGenericTypeParameter(
      _ swiftType: SwiftType,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> JavaType {
      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.qualifiedName

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }
            let wrappedType = try translateGenericTypeParameter(
              genericArgs[0],
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )
            return .class(package: "java.util", name: "Optional", typeParameters: [wrappedType])

          case .array:
            guard let elementType = nominalType.genericArguments?.first else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }
            let elementJavaType = try translateGenericTypeParameter(
              elementType,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )
            return .array(elementJavaType)

          case .dictionary:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 2 else {
              throw JavaTranslationError.dictionaryRequiresKeyAndValueTypes(swiftType)
            }
            let keyJavaType = try translateGenericTypeParameter(
              genericArgs[0],
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )
            let valueJavaType = try translateGenericTypeParameter(
              genericArgs[1],
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )
            return .swiftDictionaryMap(keyJavaType, valueJavaType)

          case .set:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.setRequiresElementType(swiftType)
            }
            let elementJavaType = try translateGenericTypeParameter(
              genericArgs[0],
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )
            return .swiftSet(elementJavaType)

          case .foundationDate, .essentialsDate:
            return .class(package: nil, name: "Date")

          case .foundationData, .essentialsData:
            return .class(package: nil, name: "Data")

          case .foundationDataProtocol, .essentialsDataProtocol:
            return .class(package: nil, name: "DataProtocol")

          case .foundationUUID, .essentialsUUID:
            return .javaUtilUUID

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config) else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }
            return javaType.boxedType
          }
        }

        if nominalType.isSwiftJavaWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromSwiftJavaName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftType)
          }
          return javaType
        }

        // We assume this is a JExtract class.
        let typeParameters =
          try nominalType.genericArguments?.map { swiftType in
            try translateGenericTypeParameter(
              swiftType,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements,
            )
          } ?? []

        return .class(
          package: dependentJavaPackages[nominalType.nominalTypeDecl.moduleName],
          name: nominalTypeName,
          typeParameters: typeParameters,
        )

      case .genericParameter(let generic):
        if let concreteTy = swiftType.typeIn(
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        ) {
          return try translateGenericTypeParameter(
            concreteTy,
            genericParameters: genericParameters,
            genericRequirements: genericRequirements,
          )
        }
        return .class(package: nil, name: generic.name)

      case .metatype, .tuple, .function, .existential, .opaque, .composite:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    /// - Parameter: methodName is necessary because we may need to form an ad-hoc one off type if e.g. named tuples are used.
    func translateTupleResult(
      methodName: String,
      elements: [SwiftTupleElement],
      resultName: String = "result",
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedResult {
      var outParameters: [OutParameter] = []
      var elementOutParamNames: [String] = []
      var elementConversions: [JavaNativeConversionStep] = []
      var elementJavaTypes: [JavaType] = []

      for (idx, element) in elements.enumerated() {
        let outParamName = "\(resultName)_\(idx)$"

        // Determine the Java type for this element
        let elementResult = try translate(
          swiftResult: .init(convention: .indirect, type: element.type),
          methodName: methodName,
          resultName: outParamName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )

        // out names are always ...$N, no need to use real named tuple names here, this is just for the thunk
        elementOutParamNames.append(outParamName)

        // FIXME: More accurate determination of whether the result is direct or indirect
        if elementResult.outParameters.isEmpty {
          // Convert direct result to indirect result.
          // For most class types (Swift wrapper classes), the JNI native representation
          // is 'long' (a memory address). However, String is a native JNI reference
          // type and must keep its original type so the out-parameter array matches
          // the native method signature (String[] not long[])
          let nativeElementType: JavaType
          if elementResult.javaType.isString {
            nativeElementType = elementResult.javaType
          } else if case .class = elementResult.javaType {
            nativeElementType = .long
          } else {
            nativeElementType = elementResult.javaType
          }
          let arrayType: JavaType = .array(nativeElementType)
          outParameters.append(
            OutParameter(name: outParamName, type: arrayType, allocation: .newArray(nativeElementType, size: 1))
          )
          elementConversions.append(elementResult.conversion)
        } else {
          outParameters.append(contentsOf: elementResult.outParameters)
          elementConversions.append(.placeToVar(elementResult.conversion, name: "\(resultName)_\(idx)"))
        }
        elementJavaTypes.append(elementResult.javaType)
      }

      let isNamedTuple = elements.contains { $0.label != nil }
      let names = elements.enumerated().map { idx, element in
        if let label = element.label {
          label
        } else {
          "$\(idx)"
        }
      }

      let tupleElements: [(outParamName: String, elementConversion: JavaNativeConversionStep)] =
        zip(elementOutParamNames, elementConversions).map { ($0, $1) }

      let javaResultType: JavaType =
        if isNamedTuple {
          .labeledTuple(methodName, names: names, elementTypes: elementJavaTypes)
        } else {
          .tuple(elementTypes: elementJavaTypes)
        }

      let javaNativeConversionStep: JavaNativeConversionStep =
        .tupleFromOutParams(
          // try!-safe, because we know the result type is a class here (a Tuple of some form)
          tupleClassName: "\(javaResultType)",
          elements: tupleElements
        )

      // Collect annotations from tuple elements - if any element is @Unsigned,
      // propagate that to the method level
      var tupleAnnotations: [JavaAnnotation] = []
      for element in elements {
        let elementAnnotations = getJavaTypeAnnotations(swiftType: element.type, config: config)
        for annotation in elementAnnotations where !tupleAnnotations.contains(annotation) {
          tupleAnnotations.append(annotation)
        }
      }

      return TranslatedResult(
        javaType: javaResultType,
        annotations: tupleAnnotations,
        outParameters: outParameters,
        conversion: javaNativeConversionStep
      )
    }

    func translateOptionalResult(
      wrappedType swiftType: SwiftType,
      resultName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedResult {
      let discriminatorName = "\(resultName)$_discriminator$"

      let parameterAnnotations: [JavaAnnotation] = getJavaTypeAnnotations(swiftType: swiftType, config: config)

      switch swiftType {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .foundationDate, .essentialsDate:
            // Handled as wrapped struct
            break

          case .foundationData, .essentialsData:
            // Handled as wrapped struct
            break

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config) else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            guard let returnType = javaType.optionalType, let optionalClass = javaType.optionalWrapperType else {
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            // Check if we can fit the value and a discriminator byte in a primitive.
            // so the return JNI value will be (value, discriminator)
            if let nextIntergralTypeWithSpaceForByte = javaType.nextIntergralTypeWithSpaceForByte {
              return TranslatedResult(
                javaType: .class(package: nil, name: returnType),
                annotations: parameterAnnotations,
                outParameters: [],
                conversion: .combinedValueToOptional(
                  .placeholder,
                  nextIntergralTypeWithSpaceForByte.javaType,
                  resultName: resultName,
                  valueType: javaType,
                  valueSizeInBytes: nextIntergralTypeWithSpaceForByte.valueBytes,
                  optionalType: optionalClass,
                ),
              )
            } else {
              // Otherwise, we return the result as normal, but
              // use an indirect return for the discriminator.
              return TranslatedResult(
                javaType: .class(package: nil, name: returnType),
                annotations: parameterAnnotations,
                outParameters: [
                  OutParameter(name: discriminatorName, type: .array(.byte), allocation: .newArray(.byte, size: 1))
                ],
                conversion: .toOptionalFromIndirectReturn(
                  discriminatorName: .constant(discriminatorName),
                  optionalClass: optionalClass,
                  nativeResultJavaType: javaType,
                  toValue: .placeholder,
                  resultName: resultName,
                ),
              )
            }
          }
        }

        guard !nominalType.isSwiftJavaWrapper else {
          throw JavaTranslationError.unsupportedSwiftType(swiftType)
        }

        // We assume this is a JExtract class.
        let javaType = try translateGenericTypeParameter(
          swiftType,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )

        let wrappedValueResult = try translate(
          swiftResult: SwiftResult(convention: .direct, type: swiftType),
          methodName: "",
          resultName: resultName + "Wrapped$",
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )

        // FIXME: More accurate JavaType using NativeJavaTranslation results directly
        let nativeResultJavaType: JavaType =
          if wrappedValueResult.outParameters.isEmpty {
            .long
          } else {
            .void
          }

        let returnType = JavaType.class(package: nil, name: "Optional", typeParameters: [javaType])
        return TranslatedResult(
          javaType: returnType,
          annotations: parameterAnnotations,
          outParameters: [
            OutParameter(name: discriminatorName, type: .array(.byte), allocation: .newArray(.byte, size: 1))
          ] + wrappedValueResult.outParameters,
          conversion: .toOptionalFromIndirectReturn(
            discriminatorName: .constant(discriminatorName),
            optionalClass: "Optional",
            nativeResultJavaType: nativeResultJavaType,
            toValue: wrappedValueResult.conversion,
            resultName: resultName
          )
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func translateArrayParameter(
      elementType: SwiftType,
      parameterName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedParameter {
      let parameterAnnotations: [JavaAnnotation] = getJavaTypeAnnotations(swiftType: elementType, config: config)

      switch elementType {
      case .nominal(let nominalType) where nominalType.nominalTypeDecl.knownTypeKind == .array:
        guard let fullKnownType = nominalType.asKnownType else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }

        guard case .array(let innerElement) = fullKnownType else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }

        let innerParam = try translateArrayParameter(
          elementType: innerElement,
          parameterName: parameterName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )
        let innerJavaType = innerParam.parameter.type.javaType
        return TranslatedParameter(
          parameter: JavaParameter(name: parameterName, type: .array(innerJavaType), annotations: parameterAnnotations),
          conversion: .requireNonNull(.placeholder, message: "\(parameterName) must not be null")
        )

      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config) else {
            throw JavaTranslationError.unsupportedSwiftType(elementType)
          }

          return TranslatedParameter(
            parameter: JavaParameter(name: parameterName, type: .array(javaType), annotations: parameterAnnotations),
            conversion: .requireNonNull(.placeholder, message: "\(parameterName) must not be null"),
          )
        }

        guard !nominalType.isSwiftJavaWrapper else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }

        let javaType = try translateGenericTypeParameter(
          elementType,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )
        // Assume JExtract imported class
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .array(javaType),
            annotations: parameterAnnotations,
          ),
          conversion: .method(
            .method(
              .arraysStream(.requireNonNull(.placeholder, message: "\(parameterName) must not be null")),
              function: "mapToLong",
              arguments: [.constant("\(javaType)::$memoryAddress")],
            ),
            function: "toArray",
            arguments: [],
          ),
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(elementType)
      }
    }

    func translateArrayResult(
      elementType: SwiftType,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedResult {
      let annotations: [JavaAnnotation] = getJavaTypeAnnotations(swiftType: elementType, config: config)

      switch elementType {
      case .nominal(let nominalType) where nominalType.nominalTypeDecl.knownTypeKind == .array:
        guard let fullKnownType = nominalType.asKnownType else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }

        guard case .array(let innerElement) = fullKnownType else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }

        let innerResult = try translateArrayResult(
          elementType: innerElement,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )
        return TranslatedResult(
          javaType: .array(innerResult.javaType),
          annotations: annotations,
          outParameters: [],
          conversion: .placeholder
        )

      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config) else {
            throw JavaTranslationError.unsupportedSwiftType(elementType)
          }

          return TranslatedResult(
            javaType: .array(javaType),
            annotations: annotations,
            outParameters: [],
            conversion: .placeholder,
          )
        }

        guard !nominalType.isSwiftJavaWrapper else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }

        let javaType = try translateGenericTypeParameter(
          elementType,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements,
        )
        // We assume this is a JExtract class.
        return TranslatedResult(
          javaType: .array(javaType),
          annotations: annotations,
          outParameters: [],
          conversion: .method(
            .method(
              .arraysStream(.placeholder),
              function: "mapToObj",
              arguments: [
                .lambda(
                  args: ["pointer"],
                  body: .wrapMemoryAddressUnsafe(.constant("pointer"), javaType),
                )
              ],
            ),
            function: "toArray",
            arguments: [.constant("\(javaType.rawClassReference)[]::new")]
          )
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(elementType)
      }
    }

    func javaTypeForDictionaryComponent(
      _ swiftType: SwiftType,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> JavaType {
      try translateGenericTypeParameter(
        swiftType,
        genericParameters: genericParameters,
        genericRequirements: genericRequirements,
      )
    }

    func translateDictionaryParameter(
      keyType: SwiftType,
      valueType: SwiftType,
      parameterName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedParameter {
      let keyJavaType = try javaTypeForDictionaryComponent(
        keyType,
        genericParameters: genericParameters,
        genericRequirements: genericRequirements,
      )
      let valueJavaType = try javaTypeForDictionaryComponent(
        valueType,
        genericParameters: genericParameters,
        genericRequirements: genericRequirements,
      )
      let dictType = JavaType.swiftDictionaryMap(keyJavaType, valueJavaType)

      return TranslatedParameter(
        parameter: JavaParameter(name: parameterName, type: dictType),
        conversion: .method(
          .requireNonNull(.placeholder, message: "\(parameterName) must not be null"),
          function: "$memoryAddress",
          arguments: [],
        ),
      )
    }

    func translateDictionaryResult(
      keyType: SwiftType,
      valueType: SwiftType,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedResult {
      let keyJavaType = try javaTypeForDictionaryComponent(
        keyType,
        genericParameters: genericParameters,
        genericRequirements: genericRequirements,
      )
      let valueJavaType = try javaTypeForDictionaryComponent(
        valueType,
        genericParameters: genericParameters,
        genericRequirements: genericRequirements,
      )
      let dictType = JavaType.swiftDictionaryMap(keyJavaType, valueJavaType)

      return TranslatedResult(
        javaType: dictType,
        outParameters: [],
        conversion: .wrapMemoryAddressUnsafe(.placeholder, dictType),
      )
    }

    func translateSetParameter(
      elementType: SwiftType,
      parameterName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedParameter {
      let elementJavaType = try javaTypeForDictionaryComponent(
        elementType,
        genericParameters: genericParameters,
        genericRequirements: genericRequirements,
      )
      let setType = JavaType.swiftSet(elementJavaType)

      return TranslatedParameter(
        parameter: JavaParameter(name: parameterName, type: setType),
        conversion: .method(
          .requireNonNull(.placeholder, message: "\(parameterName) must not be null"),
          function: "$memoryAddress",
          arguments: [],
        ),
      )
    }

    func translateSetResult(
      elementType: SwiftType,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement],
    ) throws -> TranslatedResult {
      let elementJavaType = try javaTypeForDictionaryComponent(
        elementType,
        genericParameters: genericParameters,
        genericRequirements: genericRequirements,
      )
      let setType = JavaType.swiftSet(elementJavaType)

      return TranslatedResult(
        javaType: setType,
        outParameters: [],
        conversion: .wrapMemoryAddressUnsafe(.placeholder, setType),
      )
    }
  }

  struct TranslatedEnumCase {
    /// The corresponding Java case class (CamelCased)
    let name: String

    /// The name of the translated enum
    let enumName: String

    /// The oringinal enum case.
    let original: ImportedEnumCase

    /// A list of the translated associated values
    let translatedValues: [TranslatedParameter]

    /// A list of parameter conversions
    let parameterConversions: [(translated: TranslatedResult, native: NativeResult)]

    let getAsCaseFunction: TranslatedFunctionDecl

    /// Returns whether the parameters require an arena
    var requiresSwiftArena: Bool {
      parameterConversions.contains(where: \.translated.conversion.requiresSwiftArena)
    }
  }

  struct TranslatedFunctionDecl {
    /// Java function name
    let name: String

    let isStatic: Bool

    let isThrowing: Bool

    let isAsync: Bool

    /// The name of the native function
    let nativeFunctionName: String

    /// The name of the Java parent scope this function is declared in
    let parentName: SwiftQualifiedTypeName

    /// Functional interfaces required for the Java method.
    let functionTypes: [TranslatedFunctionType]

    /// Function signature of the Java function the user will call
    let translatedFunctionSignature: TranslatedFunctionSignature

    /// Function signature of the native function that will be implemented by Swift
    let nativeFunctionSignature: NativeFunctionSignature

    /// Annotations to include on the Java function declaration
    var annotations: [JavaAnnotation] {
      self.translatedFunctionSignature.annotations
    }

    func throwsClause() -> String {
      guard !translatedFunctionSignature.exceptions.isEmpty else {
        return isThrowing && !isAsync ? " throws Exception" : ""
      }

      let signatureExceptions = translatedFunctionSignature.exceptions.compactMap(\.type.className).joined(
        separator: ", "
      )
      return " throws \(signatureExceptions)\(isThrowing ? ", Exception" : "")"
    }
  }

  struct TranslatedFunctionSignature {
    var selfParameter: TranslatedParameter?
    var selfTypeParameter: TranslatedParameter?
    var parameters: [TranslatedParameter]
    var resultType: TranslatedResult
    var exceptions: [JavaExceptionType]

    // if the result type implied any annotations,
    // propagate them onto the function the result is returned from
    var annotations: [JavaAnnotation] {
      self.resultType.annotations
    }

    var requiresSwiftArena: Bool {
      self.resultType.conversion.requiresSwiftArena
    }
  }

  /// Represent a Swift API parameter translated to Java.
  struct TranslatedParameter {
    let parameter: JavaParameter
    let conversion: JavaNativeConversionStep
  }

  /// Represent a Swift API result translated to Java.
  struct TranslatedResult {
    let javaType: JavaType

    /// Java annotations that should be propagated from the result type onto the method
    var annotations: [JavaAnnotation] = []

    let outParameters: [OutParameter]

    /// Represents how to convert the Java native result into a user-facing result.
    var conversion: JavaNativeConversionStep
  }

  struct OutParameter {
    enum Allocation {
      case newArray(JavaType, size: Int)
      case new

      func render(type: JavaType) -> String {
        switch self {
        case .newArray(let javaType, let size):
          // For array element types like byte[], we need "new byte[size][]"
          // not "new byte[][size]"
          var baseType = javaType
          var extraDimensions = ""
          while case .array(let inner) = baseType {
            extraDimensions += "[]"
            baseType = inner
          }
          return "new \(baseType)[\(size)]\(extraDimensions)"

        case .new:
          return "new \(type)()"
        }
      }
    }

    let name: String
    let type: JavaType
    let allocation: Allocation

    var javaParameter: JavaParameter {
      JavaParameter(name: self.name, type: self.type)
    }
  }

  /// Represent a Swift closure type in the user facing Java API.
  ///
  /// Closures are translated to named functional interfaces in Java.
  struct TranslatedFunctionType {
    var name: String
    var parameters: [TranslatedParameter]
    var result: TranslatedResult
    var swiftType: SwiftFunctionType
  }

  /// Describes how to convert values between Java types and the native Java function
  enum JavaNativeConversionStep {
    /// The value being converted
    case placeholder

    case constant(String)

    /// `input_component`
    case combinedName(component: String)

    // Convert the results of the inner steps to a comma separated list.
    indirect case commaSeparated([JavaNativeConversionStep])

    /// `value.$memoryAddress()`
    indirect case valueMemoryAddress(JavaNativeConversionStep)

    /// `value.$typeMetadataAddress()`
    indirect case typeMetadataAddress(JavaNativeConversionStep)

    /// Call `new \(Type)(\(placeholder), swiftArena)`
    indirect case constructSwiftValue(JavaNativeConversionStep, JavaType)

    /// Call `new \(Type)(\(placeholder))`
    indirect case constructJavaClass(JavaNativeConversionStep, JavaType)

    /// Call the `MyType.wrapMemoryAddressUnsafe` in order to wrap a memory address using the Java binding type
    indirect case wrapMemoryAddressUnsafe(JavaNativeConversionStep, JavaType)

    indirect case call(JavaNativeConversionStep, function: String)

    indirect case method(JavaNativeConversionStep, function: String, arguments: [JavaNativeConversionStep] = [])

    indirect case member(JavaNativeConversionStep, field: String)

    case isOptionalPresent

    indirect case combinedValueToOptional(
      JavaNativeConversionStep,
      JavaType,
      resultName: String,
      valueType: JavaType,
      valueSizeInBytes: Int,
      optionalType: String,
    )

    indirect case ternary(
      JavaNativeConversionStep,
      thenExp: JavaNativeConversionStep,
      elseExp: JavaNativeConversionStep,
    )

    indirect case equals(JavaNativeConversionStep, JavaNativeConversionStep)

    indirect case subscriptOf(JavaNativeConversionStep, arguments: [JavaNativeConversionStep])

    static func toOptionalFromIndirectReturn(
      discriminatorName: JavaNativeConversionStep,
      optionalClass: String,
      nativeResultJavaType: JavaType,
      toValue valueConversion: JavaNativeConversionStep,
      resultName: String,
    ) -> JavaNativeConversionStep {
      .aggregate(
        variable: nativeResultJavaType.isVoid ? nil : (name: "\(resultName)$", type: nativeResultJavaType),
        [
          .ternary(
            .equals(
              .subscriptOf(discriminatorName, arguments: [.constant("0")]),
              .constant("1"),
            ),
            thenExp: .method(.constant(optionalClass), function: "of", arguments: [valueConversion]),
            elseExp: .method(.constant(optionalClass), function: "empty"),
          )
        ],
      )
    }

    /// Perform multiple conversions using the same input.
    case aggregate(variable: (name: String, type: JavaType)? = nil, [JavaNativeConversionStep])

    indirect case ifStatement(
      JavaNativeConversionStep,
      thenExp: JavaNativeConversionStep,
      elseExp: JavaNativeConversionStep? = nil,
    )

    /// Access a member of the value
    indirect case replacingPlaceholder(JavaNativeConversionStep, placeholder: String)

    /// `(args) -> { return body; }`
    indirect case lambda(args: [String] = [], body: JavaNativeConversionStep)

    /// Prints the conversion step, ignoring the output.
    indirect case print(JavaNativeConversionStep)

    indirect case requireNonNull(JavaNativeConversionStep, message: String)

    /// Constructs a TupleN from out-parameter arrays.
    /// E.g. `new Tuple2<>(result_0$[0], result_1$[0])`
    case tupleFromOutParams(tupleClassName: String, elements: [(outParamName: String, elementConversion: JavaNativeConversionStep)])

    indirect case placeToVar(JavaNativeConversionStep, name: String)

    /// `Arrays.stream(args)`
    static func arraysStream(_ argument: JavaNativeConversionStep) -> JavaNativeConversionStep {
      .method(.constant("Arrays"), function: "stream", arguments: [argument])
    }

    /// Returns the conversion string applied to the placeholder.
    func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
      // NOTE: 'printer' is used if the conversion wants to cause side-effects.
      // E.g. storing a temporary values into a variable.
      switch self {
      case .placeholder:
        return placeholder

      case .constant(let value):
        return value

      case .combinedName(let component):
        return "\(placeholder)_\(component)"

      case .commaSeparated(let list):
        return list.map({ $0.render(&printer, placeholder) }).joined(separator: ", ")

      case .valueMemoryAddress:
        return "\(placeholder).$memoryAddress()"

      case .typeMetadataAddress(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).$typeMetadataAddress()"

      case .constructSwiftValue(let inner, let javaType):
        let inner = inner.render(&printer, placeholder)
        return "new \(javaType)(\(inner), swiftArena)"

      case .wrapMemoryAddressUnsafe(let inner, let javaType):
        let inner = inner.render(&printer, placeholder)
        guard case .class(_, let className, let typeParameters) = javaType else {
          fatalError("\(javaType) is not class.")
        }
        let genericClause =
          if !typeParameters.isEmpty {
            "<\(typeParameters.map(\.description).joined(separator: ", "))>"
          } else {
            ""
          }
        return "\(javaType.rawClassReference).\(genericClause)wrapMemoryAddressUnsafe(\(inner), swiftArena)"

      case .constructJavaClass(let inner, let javaType):
        let inner = inner.render(&printer, placeholder)
        return "new \(javaType)(\(inner))"

      case .call(let inner, let function):
        let inner = inner.render(&printer, placeholder)
        return "\(function)(\(inner))"

      case .isOptionalPresent:
        return "(byte) (\(placeholder).isPresent() ? 1 : 0)"

      case .method(let inner, let methodName, let arguments):
        let inner = inner.render(&printer, placeholder)
        let args = arguments.map { $0.render(&printer, placeholder) }
        let argsStr = args.joined(separator: ", ")
        return "\(inner).\(methodName)(\(argsStr))"

      case .member(let inner, let fieldName):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).\(fieldName)"

      case .combinedValueToOptional(
        let combined,
        let combinedType,
        let resultName,
        let valueType,
        let valueSizeInBytes,
        let optionalType,
      ):
        let combined = combined.render(&printer, placeholder)
        printer.print(
          """
          \(combinedType) \(resultName)_combined$ = \(combined);
          byte \(resultName)_discriminator$ = (byte) (\(resultName)_combined$ & 0xFF);
          """
        )

        if valueType == .boolean {
          printer.print("boolean \(resultName)_value$ = ((byte) (\(resultName)_combined$ >> 8)) != 0;")
        } else {
          printer.print(
            "\(valueType) \(resultName)_value$ = (\(valueType)) (\(resultName)_combined$ >> \(valueSizeInBytes * 8));"
          )
        }

        return "\(resultName)_discriminator$ == 1 ? \(optionalType).of(\(resultName)_value$) : \(optionalType).empty()"

      case .ternary(let cond, let thenExp, let elseExp):
        let cond = cond.render(&printer, placeholder)
        let thenExp = thenExp.render(&printer, placeholder)
        let elseExp = elseExp.render(&printer, placeholder)
        return "(\(cond)) ? \(thenExp) : \(elseExp)"

      case .equals(let lhs, let rhs):
        let lhs = lhs.render(&printer, placeholder)
        let rhs = rhs.render(&printer, placeholder)
        return "\(lhs) == \(rhs)"

      case .subscriptOf(let inner, let arguments):
        let inner = inner.render(&printer, placeholder)
        let arguments = arguments.map { $0.render(&printer, placeholder) }
        return "\(inner)[\(arguments.joined(separator: ", "))]"

      case .aggregate(let variable, let steps):
        precondition(!steps.isEmpty, "Aggregate must contain steps")
        let toExplode: String
        if let variable {
          printer.print("\(variable.type) \(variable.name) = \(placeholder);")
          toExplode = variable.name
        } else {
          toExplode = placeholder
        }
        let steps = steps.map {
          $0.render(&printer, toExplode)
        }
        return steps.last!

      case .ifStatement(let cond, let thenExp, let elseExp):
        let cond = cond.render(&printer, placeholder)
        printer.printIfBlock("\(cond)") { printer in
          printer.print(thenExp.render(&printer, placeholder))
        }
        if let elseExp {
          printer.printBraceBlock("else") { printer in
            printer.print(elseExp.render(&printer, placeholder))
          }
        }

        return ""

      case .replacingPlaceholder(let inner, let placeholder):
        return inner.render(&printer, placeholder)

      case .lambda(let args, let body):
        var printer = CodePrinter()
        printer.printBraceBlock("(\(args.joined(separator: ", "))) ->") { printer in
          let body = body.render(&printer, placeholder)
          if !body.isEmpty {
            printer.print("return \(body);")
          } else {
            printer.print("return;")
          }
        }
        return printer.finalize()

      case .print(let inner):
        let inner = inner.render(&printer, placeholder)
        printer.print("\(inner);")
        return ""

      case .requireNonNull(let inner, let message):
        let inner = inner.render(&printer, placeholder)
        return #"Objects.requireNonNull(\#(inner), "\#(message)")"#

      case .tupleFromOutParams(let tupleClassName, let elements):
        var args: [String] = []
        for element in elements {
          let converted = element.elementConversion.render(&printer, "\(element.outParamName)[0]")
          args.append(converted)
        }
        return "new \(tupleClassName)(\(args.joined(separator: ", ")))"

      case .placeToVar(let inner, let name):
        let inner = inner.render(&printer, placeholder)
        printer.print("var \(name) = \(inner);")
        return name
      }
    }

    /// Whether the conversion uses SwiftArena.
    var requiresSwiftArena: Bool {
      switch self {
      case .placeholder, .constant, .isOptionalPresent, .combinedName:
        return false

      case .constructSwiftValue, .wrapMemoryAddressUnsafe:
        return true

      case .constructJavaClass(let inner, _):
        return inner.requiresSwiftArena

      case .valueMemoryAddress(let inner):
        return inner.requiresSwiftArena

      case .typeMetadataAddress(let inner):
        return inner.requiresSwiftArena

      case .commaSeparated(let list):
        return list.contains(where: { $0.requiresSwiftArena })

      case .method(let inner, _, let args):
        return inner.requiresSwiftArena || args.contains(where: \.requiresSwiftArena)

      case .member(let inner, _):
        return inner.requiresSwiftArena

      case .combinedValueToOptional(let inner, _, _, _, _, _):
        return inner.requiresSwiftArena

      case .ternary(let cond, let thenExp, let elseExp):
        return cond.requiresSwiftArena || thenExp.requiresSwiftArena || elseExp.requiresSwiftArena

      case .equals(let lhs, let rhs):
        return lhs.requiresSwiftArena || rhs.requiresSwiftArena

      case .subscriptOf(let inner, _):
        return inner.requiresSwiftArena

      case .aggregate(_, let steps):
        return steps.contains(where: \.requiresSwiftArena)

      case .ifStatement(let cond, let thenExp, let elseExp):
        return cond.requiresSwiftArena || thenExp.requiresSwiftArena || (elseExp?.requiresSwiftArena ?? false)

      case .call(let inner, _):
        return inner.requiresSwiftArena

      case .replacingPlaceholder(let inner, _):
        return inner.requiresSwiftArena

      case .lambda(_, let body):
        return body.requiresSwiftArena

      case .print(let inner):
        return inner.requiresSwiftArena

      case .requireNonNull(let inner, _):
        return inner.requiresSwiftArena

      case .tupleFromOutParams(_, let elements):
        return elements.contains(where: { $0.elementConversion.requiresSwiftArena })

      case .placeToVar(let inner, _):
        return inner.requiresSwiftArena
      }
    }
  }

  enum JavaTranslationError: Error {
    case unsupportedSwiftType(SwiftType, fileID: String, line: Int)

    static func unsupportedSwiftType(
      _ type: SwiftType,
      _fileID: String = #fileID,
      _line: Int = #line,
    ) -> JavaTranslationError {
      .unsupportedSwiftType(type, fileID: _fileID, line: _line)
    }

    case unsupportedSwiftType(known: SwiftKnownType, fileID: String, line: Int)
    static func unsupportedSwiftType(
      known type: SwiftKnownType,
      _fileID: String = #fileID,
      _line: Int = #line,
    ) -> JavaTranslationError {
      .unsupportedSwiftType(known: type, fileID: _fileID, line: _line)
    }

    /// The user has not supplied a mapping from `SwiftType` to
    /// a java class.
    case wrappedJavaClassTranslationNotProvided(SwiftType)

    // FIXME: Remove once we support protocol variables
    case protocolVariablesNotSupported

    case protocolStaticRequirementsNotSupported

    /// We cannot generate interface wrappers for
    /// protocols that we unable to be jextracted.
    case protocolWasNotExtracted

    /// Dictionary type requires exactly two generic type arguments (key and value).
    case dictionaryRequiresKeyAndValueTypes(SwiftType)

    /// Set type requires exactly one generic type argument (element).
    case setRequiresElementType(SwiftType)

    /// Empty tuples are not supported in lowering, they should be treated as Void
    case emptyTuple(file: String, line: Int)
    static func emptyTuple(
      _file: String = #fileID,
      _line: Int = #line
    ) -> JavaTranslationError {
      .emptyTuple(file: _file, line: _line)
    }
  }
}
