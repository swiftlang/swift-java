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

import JavaTypes
import JavaKitConfigurationShared

extension JNISwift2JavaGenerator {
  func translatedDecl(
    for decl: ImportedFunc
  ) -> TranslatedFunctionDecl? {
    if let cached = translatedDecls[decl] {
      return cached
    }

    let translated: TranslatedFunctionDecl?
    do {
      let translation = JavaTranslation(
        config: config,
        swiftModuleName: swiftModuleName,
        javaPackage: self.javaPackage,
        javaClassLookupTable: self.javaClassLookupTable
      )
      translated = try translation.translate(decl)
    } catch {
      self.logger.debug("Failed to translate: '\(decl.swiftDecl.qualifiedNameForDebug)'; \(error)")
      translated = nil
    }

    translatedDecls[decl] = translated
    return translated
  }

  struct JavaTranslation {
    let config: Configuration
    let swiftModuleName: String
    let javaPackage: String
    let javaClassLookupTable: JavaClassLookupTable

    func translate(_ decl: ImportedFunc) throws -> TranslatedFunctionDecl {
      let nativeTranslation = NativeJavaTranslation(
        config: self.config,
        javaPackage: self.javaPackage,
        javaClassLookupTable: self.javaClassLookupTable
      )

      // Types with no parent will be outputted inside a "module" class.
      let parentName = decl.parentType?.asNominalType?.nominalTypeDecl.qualifiedName ?? swiftModuleName

      // Name.
      let javaName = switch decl.apiKind {
      case .getter: decl.javaGetterName
      case .setter: decl.javaSetterName
      case .function, .initializer: decl.name
      }

      // Swift -> Java
      let translatedFunctionSignature = try translate(
        functionSignature: decl.functionSignature,
        methodName: javaName,
        parentName: parentName
      )
      // Java -> Java (native)
      let nativeFunctionSignature = try nativeTranslation.translate(
        functionSignature: decl.functionSignature,
        translatedFunctionSignature: translatedFunctionSignature,
        methodName: javaName,
        parentName: parentName
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
            parentName: parentName
          )
          funcTypes.append(translatedClosure)
        default:
          break
        }
      }

      return TranslatedFunctionDecl(
        name: javaName,
        nativeFunctionName: "$\(javaName)",
        parentName: parentName,
        functionTypes: funcTypes,
        translatedFunctionSignature: translatedFunctionSignature,
        nativeFunctionSignature: nativeFunctionSignature
      )
    }

    /// Translate Swift closure type to Java functional interface.
    func translateFunctionType(
      name: String,
      swiftType: SwiftFunctionType,
      parentName: String
    ) throws -> TranslatedFunctionType {
      var translatedParams: [TranslatedParameter] = []

      for (i, param) in swiftType.parameters.enumerated() {
        let paramName = param.parameterName ?? "_\(i)"
        translatedParams.append(
          try translateParameter(swiftType: param.type, parameterName: paramName, methodName: name, parentName: parentName)
        )
      }

      let translatedResult = try translate(swiftResult: SwiftResult(convention: .direct, type: swiftType.resultType))

      return TranslatedFunctionType(
        name: name,
        parameters: translatedParams,
        result: translatedResult,
        swiftType: swiftType
      )
    }

    func translate(
      functionSignature: SwiftFunctionSignature,
      methodName: String,
      parentName: String
    ) throws -> TranslatedFunctionSignature {
      let parameters = try functionSignature.parameters.enumerated().map { idx, param in
        let parameterName = param.parameterName ?? "arg\(idx))"
        return try translateParameter(swiftType: param.type, parameterName: parameterName, methodName: methodName, parentName: parentName)
      }

      // 'self'
      let selfParameter: TranslatedParameter?
      if case .instance(let swiftSelf) = functionSignature.selfParameter {
        selfParameter = try self.translateParameter(
          swiftType: swiftSelf.type,
          parameterName: swiftSelf.parameterName ?? "self",
          methodName: methodName,
          parentName: parentName
        )
      } else {
        selfParameter = nil
      }

      let resultType = try translate(swiftResult: functionSignature.result)

      return TranslatedFunctionSignature(
        selfParameter: selfParameter,
        parameters: parameters,
        resultType: resultType
      )
    }

    func translateParameter(
      swiftType: SwiftType,
      parameterName: String,
      methodName: String,
      parentName: String
    ) throws -> TranslatedParameter {

      // If the result type should cause any annotations on the method, include them here.
      let parameterAnnotations: [JavaAnnotation] = getTypeAnnotations(swiftType: swiftType, config: config)

      // If we need to handle unsigned integers do so here
      if config.effectiveUnsignedNumbersMode.needsConversion {
        if let unsignedWrapperType = JavaType.unsignedWrapper(for: swiftType) {
          return TranslatedParameter(
            parameter: JavaParameter(name: parameterName, type: unsignedWrapperType, annotations: parameterAnnotations),
            conversion: unsignedResultConversion(
                swiftType, to: unsignedWrapperType,
                mode: self.config.effectiveUnsignedNumbersMode)
          )
        }
      }

      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config) else {
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          return TranslatedParameter(
            parameter: JavaParameter(name: parameterName, type: javaType, annotations: parameterAnnotations),
            conversion: .placeholder
          )
        }

        if nominalType.isJavaKitWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromJavaKitName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftType)
          }

          return TranslatedParameter(
            parameter: JavaParameter(name: parameterName, type: javaType, annotations: parameterAnnotations),
            conversion: .placeholder
          )
        }

        // We assume this is a JExtract class.
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .class(package: nil, name: nominalTypeName),
            annotations: parameterAnnotations
          ),
          conversion: .valueMemoryAddress(.placeholder)
        )

      case .tuple([]):
        return TranslatedParameter(
          parameter: JavaParameter(name: parameterName, type: .void, annotations: parameterAnnotations),
          conversion: .placeholder
        )

      case .function:
        return TranslatedParameter(
          parameter: JavaParameter(
            name: parameterName,
            type: .class(package: javaPackage, name: "\(parentName).\(methodName).\(parameterName)"),
            annotations: parameterAnnotations
          ),
          conversion: .placeholder
        )

      case .metatype, .optional, .tuple, .existential, .opaque, .genericParameter:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func unsignedResultConversion(_ from: SwiftType, to javaType: JavaType,
                                  mode: JExtractUnsignedIntegerMode) -> JavaNativeConversionStep {
      switch mode {
      case .annotate:
        return .placeholder // no conversions

      case .wrapGuava:
        fatalError("JExtract in JNI mode does not support the \(JExtractUnsignedIntegerMode.wrapGuava) unsigned numerics mode")
      }
    }

    func translate(swiftResult: SwiftResult) throws -> TranslatedResult {
      let swiftType = swiftResult.type

      // If the result type should cause any annotations on the method, include them here.
      let resultAnnotations: [JavaAnnotation] = getTypeAnnotations(swiftType: swiftType, config: config)

      switch swiftType {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config) else {
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          return TranslatedResult(
            javaType: javaType,
            annotations: resultAnnotations,
            conversion: .placeholder
          )
        }

        if nominalType.isJavaKitWrapper {
          throw JavaTranslationError.unsupportedSwiftType(swiftType)
        }

        // We assume this is a JExtract class.
        let javaType = JavaType.class(package: nil, name: nominalType.nominalTypeDecl.name)
        return TranslatedResult(
          javaType: javaType,
          annotations: resultAnnotations,
          conversion: .constructSwiftValue(.placeholder, javaType)
        )

      case .tuple([]):
        return TranslatedResult(javaType: .void, conversion: .placeholder)

      case .metatype, .optional, .tuple, .function, .existential, .opaque, .genericParameter:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }
  }

  struct TranslatedFunctionDecl {
    /// Java function name
    let name: String

    /// The name of the native function
    let nativeFunctionName: String

    /// The name of the Java parent scope this function is declared in
    let parentName: String

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
  }

  struct TranslatedFunctionSignature {
    var selfParameter: TranslatedParameter?
    var parameters: [TranslatedParameter]
    var resultType: TranslatedResult

    // if the result type implied any annotations,
    // propagate them onto the function the result is returned from
    var annotations: [JavaAnnotation] {
      self.resultType.annotations
    }

    var requiresSwiftArena: Bool {
      return self.resultType.conversion.requiresSwiftArena
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

    /// Represents how to convert the Java native result into a user-facing result.
    let conversion: JavaNativeConversionStep
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

    /// `value.$memoryAddress()`
    indirect case valueMemoryAddress(JavaNativeConversionStep)

    /// Call `new \(Type)(\(placeholder), swiftArena$)`
    indirect case constructSwiftValue(JavaNativeConversionStep, JavaType)

    indirect case call(JavaNativeConversionStep, function: String)

    /// Returns the conversion string applied to the placeholder.
    func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
      // NOTE: 'printer' is used if the conversion wants to cause side-effects.
      // E.g. storing a temporary values into a variable.
      switch self {
      case .placeholder:
        return placeholder

      case .valueMemoryAddress:
        return "\(placeholder).$memoryAddress()"

      case .constructSwiftValue(let inner, let javaType):
        let inner = inner.render(&printer, placeholder)
        return "new \(javaType.className!)(\(inner), swiftArena$)"

      case .call(let inner, let function):
        let inner = inner.render(&printer, placeholder)
        return "\(function)(\(inner))"

      }
    }

    /// Whether the conversion uses SwiftArena.
    var requiresSwiftArena: Bool {
      switch self {
      case .placeholder:
        return false

      case .constructSwiftValue:
        return true

      case .valueMemoryAddress(let inner):
        return inner.requiresSwiftArena

      case .call(let inner, _):
      return inner.requiresSwiftArena
      }
    }
  }

  enum JavaTranslationError: Error {
    case unsupportedSwiftType(SwiftType, fileID: String, line: Int)
    static func unsupportedSwiftType(_ type: SwiftType, _fileID: String = #fileID, _line: Int = #line) -> JavaTranslationError {
      .unsupportedSwiftType(type, fileID: _fileID, line: _line)
    }

    /// The user has not supplied a mapping from `SwiftType` to
    /// a java class.
    case wrappedJavaClassTranslationNotProvided(SwiftType)
  }
}
