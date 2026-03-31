//
//  Swift2KotlinGenerator+KotlinTranslation.swift
//  swift-java
//
//  Created by Tanish Azad on 30/03/26.
//

import SwiftJavaJNICore
import SwiftJavaConfigurationShared

extension Swift2KotlinGenerator {
  func translatedDecl(
    for decl: ImportedFunc
  ) -> TranslatedFunctionDecl? {
    if let cached = translatedDecls[decl] {
      return cached
    }

    let translated: TranslatedFunctionDecl?
    do {
      let translation = KotlinTranslation(
        config: self.config,
        knownTypes: SwiftKnownTypes(symbolTable: lookupContext.symbolTable),
        javaIdentifiers: self.currentJavaIdentifiers
      )
      translated = try translation.translate(decl)
    } catch {
      self.log.info("Failed to translate: '\(decl.swiftDecl.qualifiedNameForDebug)'; \(error)")
      translated = nil
    }

    translatedDecls[decl] = translated
    return translated
  }
  
  /// Represent a Swift API parameter translated to Kotlin.
  struct TranslatedParameter {
    /// Kotlin parameter(s) mapped to the Swift parameter.
    ///
    /// Array because one Swift parameter can be mapped to multiple parameters.
    var kotlinParameters: [KotlinParameter]

    /// Whether this parameter requires 32-bit integer overflow checking
    var needs32BitIntOverflowCheck: OverflowCheckType = .none
  }

  enum OverflowCheckType {
    case none
    case signedInt // Int: -2147483648 to 2147483647
    case unsignedInt // UInt: 0 to 4294967295
  }

  /// Represent a Swift API result translated to Java.
  struct TranslatedResult {
    /// Java type that represents the Swift result type.
    var javaResultType: JavaType

    /// Java annotations that should be propagated from the result type onto the method
    var annotations: [JavaAnnotation] = []

    /// Required indirect return receivers for receiving the result.
    ///
    /// 'JavaParameter.name' is the suffix for the receiver variable names. For example
    ///
    ///   var _result_pointer = MemorySegment.allocate(...)
    ///   var _result_count = MemorySegment.allocate(...)
    ///   downCall(_result_pointer, _result_count)
    ///   return constructResult(_result_pointer, _result_count)
    ///
    /// This case, there're two out parameter, named '_pointer' and '_count'.
    var outParameters: [KotlinParameter]

    /// Similar to out parameters, but instead of parameters we "fill in" in native,
    /// we create an upcall handle before the downcall and pass it to the downcall.
    /// Swift then invokes the upcall in order to populate some data in Java (our callback).
    ///
    /// After the call is made, we may need to further extact the result from the called-back-into
    /// Java function class, for example:
    ///
    ///   var _result_initialize = new $result_initialize.Function();
    ///   downCall($result_initialize.toUpcallHandle(_result_initialize, arena))
    ///   return _result_initialize.result
    ///
    var outCallback: OutCallback?

    /// Whether this result requires 32-bit integer overflow checking
    var needs32BitIntOverflowCheck: OverflowCheckType = .none
  }

  /// Translated Java API representing a Swift API.
  ///
  /// Since this holds the lowered signature, and the original `SwiftFunctionSignature`
  /// in it, this contains all the API information (except the name) to generate the
  /// cdecl thunk, Java binding, and the Java wrapper function.
  struct TranslatedFunctionDecl {
    /// Java function name.
    let name: String

    /// Functional interfaces required for the Java method.
    let functionTypes: [TranslatedFunctionType]

    /// Function signature.
    let translatedSignature: TranslatedFunctionSignature

    /// Cdecl lowered signature.
    let loweredSignature: LoweredFunctionSignature

    /// Annotations to include on the Java function declaration
    var annotations: [JavaAnnotation] {
      self.translatedSignature.annotations
    }
  }

  /// Function signature for a Java API.
  struct TranslatedFunctionSignature {
    var selfParameter: TranslatedParameter?
    var parameters: [TranslatedParameter]
    var result: TranslatedResult

    // if the result type implied any annotations,
    // propagate them onto the function the result is returned from
    var annotations: [JavaAnnotation] {
      self.result.annotations
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
    var cdeclType: SwiftFunctionType
  }
  
  // ==== -------------------------------------------------------------------
  // MARK: Java translation

  struct KotlinTranslation {
    let config: Configuration
    var knownTypes: SwiftKnownTypes
    var javaIdentifiers: JavaIdentifierFactory

    init(config: Configuration, knownTypes: SwiftKnownTypes, javaIdentifiers: JavaIdentifierFactory) {
      self.config = config
      self.knownTypes = knownTypes
      self.javaIdentifiers = javaIdentifiers
    }

    func translate(_ decl: ImportedFunc) throws -> TranslatedFunctionDecl {
      let lowering = CdeclLowering(knownTypes: knownTypes)
      let loweredSignature = try lowering.lowerFunctionSignature(decl.functionSignature)

      // Name.
      let javaName = javaIdentifiers.makeJavaMethodName(decl)

      // Signature.
      let translatedSignature = try translate(loweredFunctionSignature: loweredSignature, methodName: javaName)

      // Closures.
      var funcTypes: [TranslatedFunctionType] = []
      for (idx, param) in decl.functionSignature.parameters.enumerated() {
        switch param.type {
        case .function(let funcTy):
          let paramName = param.parameterName ?? "_\(idx)"
          guard case .function(let cdeclTy) = loweredSignature.parameters[idx].cdeclParameters[0].type else {
            preconditionFailure("closure parameter wasn't lowered to a function type; \(funcTy)")
          }
          let translatedClosure = try translateFunctionType(name: paramName, swiftType: funcTy, cdeclType: cdeclTy)
          funcTypes.append(translatedClosure)
        case .tuple:
          // Tuple-typed closure parameters are not supported (same as JNI / lowering).
          break
        default:
          break
        }
      }

      return TranslatedFunctionDecl(
        name: javaName,
        functionTypes: funcTypes,
        translatedSignature: translatedSignature,
        loweredSignature: loweredSignature
      )
    }

    /// Translate Swift closure type to Java functional interface.
    func translateFunctionType(
      name: String,
      swiftType: SwiftFunctionType,
      cdeclType: SwiftFunctionType
    ) throws -> TranslatedFunctionType {
      var translatedParams: [TranslatedParameter] = []

      for (i, param) in swiftType.parameters.enumerated() {
        let paramName = param.parameterName ?? "_\(i)"
        translatedParams.append(
          try translateClosureParameter(param.type, convention: param.convention, parameterName: paramName)
        )
      }

      guard let resultCType = try? CType(cdeclType: swiftType.resultType) else {
        throw JavaTranslationError.unhandledType(.function(swiftType))
      }

      let transltedResult = TranslatedResult(
        javaResultType: resultCType.javaType,
        outParameters: []
      )

      return TranslatedFunctionType(
        name: name,
        parameters: translatedParams,
        result: transltedResult,
        swiftType: swiftType,
        cdeclType: cdeclType
      )
    }

    func translateClosureParameter(
      _ type: SwiftType,
      convention: SwiftParameterConvention,
      parameterName: String
    ) throws -> TranslatedParameter {
      if let cType = try? CType(cdeclType: type) {
        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(name: parameterName, type: cType.javaType)
          ]
        )
      }

      switch type {
      case .nominal(let nominal):
        if let knownType = nominal.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
            return TranslatedParameter(
              kotlinParameters: [
                KotlinParameter(name: parameterName, type: .javaForeignMemorySegment)
              ]
            )
          default:
            break
          }
        }
      default:
        break
      }
      throw JavaTranslationError.unhandledType(type)
    }

    /// Translate a Swift API signature to the user-facing Java API signature.
    ///
    /// Note that the result signature is for the high-level Java API, not the
    /// low-level FFM down-calling interface.
    func translate(
      loweredFunctionSignature: LoweredFunctionSignature,
      methodName: String
    ) throws -> TranslatedFunctionSignature {
      let swiftSignature = loweredFunctionSignature.original

      // 'self'
      let selfParameter: TranslatedParameter?
      if case .instance(let convention, let swiftType) = swiftSignature.selfParameter {
        selfParameter = try self.translateParameter(
          type: swiftType,
          convention: convention,
          parameterName: "self",
          loweredParam: loweredFunctionSignature.selfParameter!,
          methodName: methodName,
          genericParameters: swiftSignature.genericParameters,
          genericRequirements: swiftSignature.genericRequirements
        )
      } else {
        selfParameter = nil
      }

      // Regular parameters.
      let parameters: [TranslatedParameter] = try swiftSignature.parameters.enumerated()
        .map { (idx, swiftParam) in
          let loweredParam = loweredFunctionSignature.parameters[idx]
          let parameterName = swiftParam.parameterName ?? "_\(idx)"
          return try self.translateParameter(
            type: swiftParam.type,
            convention: swiftParam.convention,
            parameterName: parameterName,
            loweredParam: loweredParam,
            methodName: methodName,
            genericParameters: swiftSignature.genericParameters,
            genericRequirements: swiftSignature.genericRequirements
          )
        }

      // Result.
      let result = try self.translateResult(
        swiftResult: swiftSignature.result,
        loweredResult: loweredFunctionSignature.result
      )

      return TranslatedFunctionSignature(
        selfParameter: selfParameter,
        parameters: parameters,
        result: result
      )
    }

    /// Translate a Swift API parameter to the user-facing Java API parameter.
    func translateParameter(
      type swiftType: SwiftType,
      convention: SwiftParameterConvention,
      parameterName: String,
      loweredParam: LoweredParameter,
      methodName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement]
    ) throws -> TranslatedParameter {
      // If the result type should cause any annotations on the method, include them here.
      let parameterAnnotations: [JavaAnnotation] = getTypeAnnotations(swiftType: swiftType, config: config)

      // If there is a 1:1 mapping between this Swift type and a C type, that can
      // be expressed as a Java primitive type.
      if let cType = try? CType(cdeclType: swiftType) {
        let javaType = cType.javaType
        let overflowCheck: OverflowCheckType
        if case .integral(.ptrdiff_t) = cType {
          overflowCheck = .signedInt
        } else if case .integral(.size_t) = cType {
          overflowCheck = .unsignedInt
        } else {
          overflowCheck = .none
        }
        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(
              name: parameterName,
              type: javaType,
              annotations: parameterAnnotations
            )
          ],
          needs32BitIntOverflowCheck: overflowCheck
        )
      }

      switch swiftType {
      case .metatype:
        // Metatype are expressed as 'org.swift.swiftkit.SwiftAnyType'
        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(
              name: parameterName,
              type: JavaType.class(package: "org.swift.swiftkit.ffm", name: "SwiftAnyType"),
              annotations: parameterAnnotations
            )
          ]
        )

      case .nominal(let swiftNominalType):
        if let knownType = swiftNominalType.nominalTypeDecl.knownTypeKind {
          if convention == .inout {
            // FIXME: Support non-trivial 'inout' for builtin types.
            throw JavaTranslationError.inoutNotSupported(swiftType)
          }
          switch knownType {
          case .unsafePointer, .unsafeMutablePointer:
            // FIXME: Implement
            throw JavaTranslationError.unhandledType(swiftType)
          case .unsafeBufferPointer, .unsafeMutableBufferPointer:
            // FIXME: Implement
            throw JavaTranslationError.unhandledType(swiftType)

          case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
            return TranslatedParameter(
              kotlinParameters: [
                KotlinParameter(name: parameterName, type: .javaForeignMemorySegment)
              ]
            )

          case .optional:
            guard let genericArgs = swiftNominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unhandledType(swiftType)
            }
            return try translateOptionalParameter(
              wrappedType: genericArgs[0],
              convention: convention,
              parameterName: parameterName,
              loweredParam: loweredParam,
              methodName: methodName,
              genericParameters: genericParameters,
              genericRequirements: genericRequirements
            )

          case .string:
            return TranslatedParameter(
              kotlinParameters: [
                KotlinParameter(
                  name: parameterName,
                  type: .javaLangString
                )
              ]
            )

          case .foundationData, .essentialsData:
            break

          default:
            throw JavaTranslationError.unhandledType(swiftType)
          }
        }

        // Generic types are not supported yet.
        guard swiftNominalType.genericArguments == nil else {
          throw JavaTranslationError.unhandledType(swiftType)
        }

        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(
              name: parameterName,
              type: try translate(swiftType: swiftType)
            )
          ]
        )

      case .tuple([]):
        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(
              name: parameterName,
              type: .void,
              annotations: parameterAnnotations
            )
          ]
        )

      case .tuple(let elements):
        return try translateTupleParameter(
          elements: elements,
          convention: convention,
          parameterName: parameterName,
          methodName: methodName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )

      case .function:
        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(
              name: parameterName,
              type: JavaType.class(package: nil, name: "\(methodName).\(parameterName)")
            )
          ]
        )

      case .existential, .opaque, .genericParameter:
        if let concreteTy = swiftType.representativeConcreteTypeIn(
          knownTypes: knownTypes,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        ) {
          return try translateParameter(
            type: concreteTy,
            convention: convention,
            parameterName: parameterName,
            loweredParam: loweredParam,
            methodName: methodName,
            genericParameters: genericParameters,
            genericRequirements: genericRequirements
          )
        }

        // Otherwise, not supported yet.
        throw JavaTranslationError.unhandledType(swiftType)

      case .optional(let wrapped):
        return try translateOptionalParameter(
          wrappedType: wrapped,
          convention: convention,
          parameterName: parameterName,
          loweredParam: loweredParam,
          methodName: methodName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )

      case .composite:
        throw JavaTranslationError.unhandledType(swiftType)

      case .array(let wrapped) where wrapped == knownTypes.uint8:
        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(name: parameterName, type: .array(.byte), annotations: parameterAnnotations)
          ]
        )

      case .array:
        throw JavaTranslationError.unhandledType(swiftType)

      case .dictionary:
        throw JavaTranslationError.unhandledType(swiftType)

      case .set:
        throw JavaTranslationError.unhandledType(swiftType)
      }
    }

    /// Tuple parameters: one `TupleN<…>` on the Java API; conversion reads `.$0`, `.$1`, … (mirrors JNI).
    func translateTupleParameter(
      elements: [SwiftTupleElement],
      convention: SwiftParameterConvention,
      parameterName: String,
      methodName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement]
    ) throws -> TranslatedParameter {
      let lowering = CdeclLowering(knownTypes: knownTypes)
      var elementJavaTypes: [JavaType] = []

      for (idx, element) in elements.enumerated() {
        let subLowered = try lowering.lowerParameter(
          element.type,
          convention: convention,
          parameterName: "\(parameterName)_\(idx)",
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )
        let elementTranslated = try translateParameter(
          type: element.type,
          convention: convention,
          parameterName: "\(parameterName)_\(idx)",
          loweredParam: subLowered,
          methodName: methodName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )
        guard elementTranslated.kotlinParameters.count == 1 else {
          throw JavaTranslationError.unhandledType(element.type)
        }
        elementJavaTypes.append(elementTranslated.kotlinParameters[0].type.javaType)
      }

      let javaType: JavaType = .tuple(elementTypes: elementJavaTypes)
      return TranslatedParameter(
        kotlinParameters: [
          KotlinParameter(name: parameterName, type: javaType)
        ]
      )
    }

    /// Translate an Optional Swift API parameter to the user-facing Java API parameter.
    func translateOptionalParameter(
      wrappedType swiftType: SwiftType,
      convention: SwiftParameterConvention,
      parameterName: String,
      loweredParam: LoweredParameter,
      methodName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement]
    ) throws -> TranslatedParameter {
      // If there is a 1:1 mapping between this Swift type and a C type, that can
      // be expressed as a Java primitive type.
      if let cType = try? CType(cdeclType: swiftType) {
        let (translatedClass, lowerFunc) =
          switch cType.javaType {
          case .int: ("Int?", "toOptionalSegmentInt")
          case .long: ("Long?", "toOptionalSegmentLong")
          case .double: ("Double?", "toOptionalSegmentDouble")
          case .boolean: ("Boolean?", "toOptionalSegmentBoolean")
          case .byte: ("Byte?", "toOptionalSegmentByte")
          case .char: ("Char?", "toOptionalSegmentCharacter")
          case .short: ("Short?", "toOptionalSegmentShort")
          case .float: ("Float?", "toOptionalSegmentFloat")
          default:
            throw JavaTranslationError.unhandledType(.optional(swiftType))
          }
        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(name: parameterName, type: JavaType(className: translatedClass))
          ]
        )
      }

      switch swiftType {
      case .nominal(let nominal):
        if let knownType = nominal.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .foundationData, .foundationDataProtocol:
            break
          case .essentialsData, .essentialsDataProtocol:
            break
          default:
            throw JavaTranslationError.unhandledType(.optional(swiftType))
          }
        }

        let translatedTy = try self.translate(swiftType: swiftType)
        return TranslatedParameter(
          kotlinParameters: [
            KotlinParameter(name: parameterName, type: JavaType(className: "\(translatedTy.description)?"))
          ]
        )
      case .existential, .opaque, .genericParameter:
        if let concreteTy = swiftType.representativeConcreteTypeIn(
          knownTypes: knownTypes,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        ) {
          return try translateOptionalParameter(
            wrappedType: concreteTy,
            convention: convention,
            parameterName: parameterName,
            loweredParam: loweredParam,
            methodName: methodName,
            genericParameters: genericParameters,
            genericRequirements: genericRequirements
          )
        }
        throw JavaTranslationError.unhandledType(.optional(swiftType))
      case .tuple(let tuple):
        if tuple.count == 1 {
          return try translateOptionalParameter(
            wrappedType: tuple[0].type,
            convention: convention,
            parameterName: parameterName,
            loweredParam: loweredParam,
            methodName: methodName,
            genericParameters: genericParameters,
            genericRequirements: genericRequirements
          )
        }
        throw JavaTranslationError.unhandledType(.optional(swiftType))
      default:
        throw JavaTranslationError.unhandledType(.optional(swiftType))
      }
    }

    /// Translate a Swift API result to the user-facing Java API result.
    func translateResult(
      swiftResult: SwiftResult,
      loweredResult: LoweredResult
    ) throws -> TranslatedResult {
      let swiftType = swiftResult.type
      // If the result type should cause any annotations on the method, include them here.
      let resultAnnotations: [JavaAnnotation] = getTypeAnnotations(swiftType: swiftType, config: config)

      // If there is a 1:1 mapping between this Swift type and a C type, that can
      // be expressed as a Java primitive type.
      if let cType = try? CType(cdeclType: swiftType) {
        let javaType = cType.javaType
        let overflowCheck: OverflowCheckType
        if case .integral(.ptrdiff_t) = cType {
          overflowCheck = .signedInt
        } else if case .integral(.size_t) = cType {
          overflowCheck = .unsignedInt
        } else {
          overflowCheck = .none
        }
        return TranslatedResult(
          javaResultType: javaType,
          annotations: resultAnnotations,
          outParameters: [],
          needs32BitIntOverflowCheck: overflowCheck
        )
      }

      switch swiftType {
      case .metatype(_):
        // Metatype are expressed as 'org.swift.swiftkit.SwiftAnyType'
        let javaType = JavaType.class(package: "org.swift.swiftkit.ffm", name: "SwiftAnyType")
        return TranslatedResult(
          javaResultType: javaType,
          annotations: resultAnnotations,
          outParameters: []
        )

      case .nominal(let swiftNominalType):
        if let knownType = swiftNominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
            return TranslatedResult(
              javaResultType: .javaForeignMemorySegment,
              annotations: resultAnnotations,
              outParameters: [
                KotlinParameter(name: "pointer", type: .javaForeignMemorySegment),
                KotlinParameter(name: "count", type: .long),
              ]
            )

          case .foundationData, .essentialsData:
            break // Implemented as wrapper

          case .unsafePointer, .unsafeMutablePointer:
            // FIXME: Implement
            throw JavaTranslationError.unhandledType(swiftType)
          case .unsafeBufferPointer, .unsafeMutableBufferPointer:
            // FIXME: Implement
            throw JavaTranslationError.unhandledType(swiftType)
          case .string:
            // FIXME: Implement
            throw JavaTranslationError.unhandledType(swiftType)
          default:
            throw JavaTranslationError.unhandledType(swiftType)
          }
        }

        // Generic types are not supported yet.
        guard swiftNominalType.genericArguments == nil else {
          throw JavaTranslationError.unhandledType(swiftType)
        }

        let javaType: JavaType = .class(package: nil, name: swiftNominalType.nominalTypeDecl.qualifiedName)
        return TranslatedResult(
          javaResultType: javaType,
          annotations: resultAnnotations,
          outParameters: [
            KotlinParameter(name: "", type: javaType)
          ]
        )

      case .tuple([]):
        return TranslatedResult(
          javaResultType: .void,
          annotations: resultAnnotations,
          outParameters: []
        )

      case .tuple(let elements):
        return try translateTupleResult(
          elements: elements,
          resultAnnotations: resultAnnotations
        )

      case .array(let wrapped) where wrapped == knownTypes.uint8:
        return TranslatedResult(
          javaResultType:
            .array(.byte),
          annotations: [.unsigned],
          outParameters: [], // no out parameters, but we do an "out" callback
          outCallback: OutCallback(
            name: "$_result_initialize",
            members: [
              "byte[] result = null"
            ],
            parameters: [
              JavaParameter(name: "pointer", type: .javaForeignMemorySegment),
              JavaParameter(name: "count", type: .long),
            ],
            cFunc: CFunction(
              resultType: .void,
              name: "apply",
              parameters: [
                CParameter(type: .pointer(.void)),
                CParameter(type: .integral(.size_t)),
              ],
              isVariadic: false
            ),
            body:
              "this.result = _0.reinterpret(_1).toArray(ValueLayout.JAVA_BYTE); // copy native Swift array to Java heap array"
          )
        )

      case .genericParameter, .optional, .function, .existential, .opaque, .composite, .array, .dictionary, .set:
        throw JavaTranslationError.unhandledType(swiftType)
      }

    }

    /// Tuple results: indirect `MemorySegment` per element, then `new TupleN<…>(…)` (mirrors JNI out-arrays).
    func translateTupleResult(
      elements: [SwiftTupleElement],
      resultAnnotations: [JavaAnnotation]
    ) throws -> TranslatedResult {
      var outParameters: [KotlinParameter] = []
      var tupleElements: [(outParamName: String, elementConversion: JavaConversionStep)] = []
      var elementJavaTypes: [JavaType] = []

      for (idx, element) in elements.enumerated() {
        let (javaType, elementConversion) = try translateTupleElementResult(type: element.type)
        outParameters.append(KotlinParameter(name: "\(idx)", type: javaType))
        tupleElements.append((outParamName: "_result_\(idx)", elementConversion: elementConversion))
        elementJavaTypes.append(javaType)
      }

      let javaResultType: JavaType = .tuple(elementTypes: elementJavaTypes)
      let fullTupleClassName = javaResultType.fullyQualifiedClassName!

      return TranslatedResult(
        javaResultType: javaResultType,
        annotations: resultAnnotations,
        outParameters: outParameters
      )
    }

    /// Single tuple element for the Java result (mirrors JNI `translateTupleElementResult`).
    private func translateTupleElementResult(type: SwiftType) throws -> (JavaType, JavaConversionStep) {
      switch type {
      case .nominal(let nominalType):
        if nominalType.nominalTypeDecl.knownTypeKind != nil {
          if let cType = try? CType(cdeclType: type) {
            return (cType.javaType, .readMemorySegment(.placeholder, as: cType.javaType))
          }
          throw JavaTranslationError.unhandledType(type)
        }

        guard !nominalType.isSwiftJavaWrapper else {
          throw JavaTranslationError.unhandledType(type)
        }

        let javaType: JavaType = .class(package: nil, name: nominalType.nominalTypeDecl.qualifiedName)
        return (javaType, .wrapMemoryAddressUnsafe(.placeholder, javaType))

      default:
        throw JavaTranslationError.unhandledType(type)
      }
    }

    func translate(
      swiftType: SwiftType
    ) throws -> JavaType {
      guard let nominalName = swiftType.asNominalTypeDeclaration?.name else {
        throw JavaTranslationError.unhandledType(swiftType)
      }
      return .class(package: nil, name: nominalName)
    }
  }

  /// Describes how to convert values between Java types and FFM types.
  enum JavaConversionStep {
    /// The input
    case placeholder

    /// The "downcall", e.g. `swiftjava_SwiftModule_returnArray.call(...)`.
    /// This can be used in combination with aggregate conversion steps to prepare a setup and processing of the downcall.
    case placeholderForDowncall

    /// Placeholder for Swift thunk name, e.g. "swiftjava_SwiftModule_returnArray".
    ///
    /// This is derived from the placeholderForDowncall substitution - could be done more cleanly,
    /// however this has the benefit of not needing to pass the name substituion separately.
    case placeholderForSwiftThunkName

    /// The temporary `arena$` that is necessary to complete the conversion steps.
    ///
    /// This is distinct from just a constant 'arena$' string, since it forces the creation of a temporary arena.
    case temporaryArena

    /// The input exploded into components.
    case explodedName(component: String)

    /// A fixed value
    case constant(String)

    /// The result of the function will be initialized with a callback to Java (an upcall).
    ///
    /// The `extractResult` is used for the actual `return ...` statement, because we need to extract
    /// the return value from the called back into class, e.g. `return _result_initialize.result`.
    indirect case initializeResultWithUpcall([JavaConversionStep], extractResult: JavaConversionStep)

    /// 'value.$memorySegment()'
    indirect case swiftValueSelfSegment(JavaConversionStep)

    /// Call specified function using the placeholder as arguments.
    ///
    /// The 'base' is if the call should be performed as 'base.function',
    /// otherwise the function is assumed to be a free function.
    ///
    /// If `withArena` is true, `arena$` argument is added.
    indirect case call(JavaConversionStep, base: JavaConversionStep?, function: String, withArena: Bool)

    static func call(_ step: JavaConversionStep, function: String, withArena: Bool) -> Self {
      .call(step, base: nil, function: function, withArena: withArena)
    }

    // TODO: just use make call more powerful and use it instead?
    /// Apply a method on the placeholder.
    /// If `withArena` is true, `arena$` argument is added.
    indirect case method(JavaConversionStep, methodName: String, arguments: [JavaConversionStep] = [], withArena: Bool)

    /// Fetch a property from the placeholder.
    /// Similar to 'method', however for a property i.e. without adding the '()' after the name
    indirect case property(JavaConversionStep, propertyName: String)

    /// Call 'new \(Type)(\(placeholder), swiftArena)'.
    indirect case constructSwiftValue(JavaConversionStep, JavaType)

    /// Construct the type using the placeholder as arguments.
    indirect case construct(JavaConversionStep, JavaType)

    /// Call the `MyType.wrapMemoryAddressUnsafe` in order to wrap a memory address using the Java binding type
    indirect case wrapMemoryAddressUnsafe(JavaConversionStep, JavaType)

    /// Introduce a local variable, e.g. `var result = new Something()`
    indirect case introduceVariable(name: String, initializeWith: JavaConversionStep)

    /// Casting the placeholder to the certain type.
    indirect case cast(JavaConversionStep, JavaType)

    /// Prefix the conversion step with a java `new`.
    ///
    /// This is useful if constructing the value is complex and we use
    /// a combination of separated values and constants to do so; Generally prefer using `construct`
    /// if you only want to construct a "wrapper" for the current `.placeholder`.
    indirect case javaNew(JavaConversionStep)

    /// Convert the results of the inner steps to a comma separated list.
    indirect case commaSeparated([JavaConversionStep], separator: String = ", ")

    /// Refer an exploded argument suffixed with `_\(name)`.
    indirect case readMemorySegment(JavaConversionStep, as: JavaType)

    /// Use `placeholder` as the root when rendering `inner` (same idea as JNI `replacingPlaceholder`).
    indirect case replacingPlaceholder(JavaConversionStep, placeholder: String)

    /// Build `org.swift.swiftkit.core.tuple.TupleN` from indirect `MemorySegment` out params (JNI `tupleFromOutParams`).
    case tupleFromOutParams(
      tupleClassName: String,
      elements: [(outParamName: String, elementConversion: JavaConversionStep)]
    )

    var isPlaceholder: Bool {
      if case .placeholder = self { true } else { false }
    }
  }
}

extension CType {
  /// Map lowered C type to Java type for FFM binding.
  var kotlinType: JavaType {
    switch self {
    case .void: return .void

    case .integral(.bool): return .boolean
    case .integral(.signed(bits: 8)): return .byte
    case .integral(.signed(bits: 16)): return .short
    case .integral(.signed(bits: 32)): return .int
    case .integral(.signed(bits: 64)): return .long
    case .integral(.unsigned(bits: 8)): return .byte
    case .integral(.unsigned(bits: 16)): return .char // char is Java's only unsigned primitive, we can use it!
    case .integral(.unsigned(bits: 32)): return .int
    case .integral(.unsigned(bits: 64)): return .long

    case .floating(.float): return .float
    case .floating(.double): return .double

    // FIXME: 32 bit consideration.
    // The 'FunctionDescriptor' uses 'SWIFT_INT' which relies on the running
    // machine arch. That means users can't pass Java 'long' values to the
    // function without casting. But how do we generate code that runs both
    // 32 and 64 bit machine?
    case .integral(.ptrdiff_t), .integral(.size_t):
      return .long

    case .pointer(_), .function(resultType: _, parameters: _, variadic: _):
      return .javaForeignMemorySegment

    case .qualified(const: _, volatile: _, let inner):
      return inner.javaType

    case .tag(_):
      fatalError("unsupported")
    case .integral(.signed(bits: _)), .integral(.unsigned(bits: _)):
      fatalError("unreachable")
    }
  }
}

enum KotlinTranslationError: Error {
  case inoutNotSupported(SwiftType, file: String = #file, line: Int = #line)
  case unhandledType(SwiftType, file: String = #file, line: Int = #line)
}
