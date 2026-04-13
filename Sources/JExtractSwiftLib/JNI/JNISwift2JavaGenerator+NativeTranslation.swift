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

  struct NativeJavaTranslation {
    let config: Configuration
    let javaPackage: String
    let javaClassLookupTable: JavaClassLookupTable
    var knownTypes: SwiftKnownTypes
    let protocolWrappers: [ImportedNominalType: JavaInterfaceSwiftWrapper]
    let logger: Logger

    /// Translates a Swift function into the native JNI method signature.
    func translate(
      functionSignature: SwiftFunctionSignature,
      translatedFunctionSignature: TranslatedFunctionSignature,
      methodName: String,
      parentName: SwiftQualifiedTypeName
    ) throws -> NativeFunctionSignature {
      let parameters = try zip(translatedFunctionSignature.parameters, functionSignature.parameters).map {
        translatedParameter,
        swiftParameter in
        let parameterName = translatedParameter.parameter.name
        return try translateParameter(
          type: swiftParameter.type,
          parameterName: parameterName,
          methodName: methodName,
          parentName: parentName,
          genericParameters: functionSignature.genericParameters,
          genericRequirements: functionSignature.genericRequirements
        )
      }

      // Lower the self parameter.
      let nativeSelf: NativeParameter? =
        switch functionSignature.selfParameter {
        case .instance(_, let swiftType):
          try translateParameter(
            type: swiftType,
            parameterName: "selfPointer",
            methodName: methodName,
            parentName: parentName,
            genericParameters: functionSignature.genericParameters,
            genericRequirements: functionSignature.genericRequirements
          )
        case nil, .initializer(_), .staticMethod(_):
          nil
        }

      let selfTypeParameter: NativeParameter? =
        if let selfType = functionSignature.selfParameter?.selfType,
          selfType.asNominalTypeDeclaration?.isGeneric == true
        {
          try translateParameter(
            type: .metatype(selfType),
            parameterName: "selfTypePointer",
            methodName: methodName,
            parentName: parentName,
            genericParameters: functionSignature.genericParameters,
            genericRequirements: functionSignature.genericRequirements
          )
        } else {
          nil
        }

      let result = try translate(swiftResult: functionSignature.result, methodName: methodName)

      return NativeFunctionSignature(
        selfParameter: nativeSelf,
        selfTypeParameter: selfTypeParameter,
        parameters: parameters,
        result: result
      )
    }

    func translateParameter(
      type: SwiftType,
      parameterName: String,
      methodName: String,
      parentName: SwiftQualifiedTypeName,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement]
    ) throws -> NativeParameter {
      switch type {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.asKnownType {
          switch knownType {
          case .optional(let wrapped):
            return try translateOptionalParameter(
              wrappedType: wrapped,
              parameterName: parameterName
            )

          case .array(let element):
            return try translateArrayParameter(elementType: element, parameterName: parameterName)

          case .dictionary(let key, let value):
            return try translateDictionaryParameter(
              keyType: key,
              valueType: value,
              parameterName: parameterName
            )

          case .set(let element):
            return try translateSetParameter(
              elementType: element,
              parameterName: parameterName
            )

          case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
            let isMutable = knownType.kind == .unsafeMutableRawBufferPointer
            return NativeParameter(
              parameters: [
                JavaParameter(name: parameterName, type: .array(.byte))
              ],
              conversion: .jniByteArrayToUnsafeRawBufferPointer(.placeholder, name: parameterName, mutable: isMutable),
              indirectConversion: nil,
              conversionCheck: nil
            )

          case .foundationDate, .essentialsDate, .foundationData, .essentialsData:
            // Handled as wrapped struct
            break

          case .foundationUUID, .essentialsUUID:
            let uuidStringVariable = "\(parameterName)_string$"
            let initUUIDStep = NativeSwiftConversionStep.unwrapOptional(
              .method(
                .constant("UUID"),
                function: "init",
                arguments: [("uuidString", .placeholder)]
              ),
              name: parameterName,
              fatalErrorMessage: "Invalid UUID string passed from Java: \\(\(uuidStringVariable))"
            )

            return NativeParameter(
              parameters: [
                JavaParameter(name: parameterName, type: .javaLangString)
              ],
              conversion: .replacingPlaceholder(
                .aggregate(
                  variable: uuidStringVariable,
                  [initUUIDStep]
                ),
                placeholder: .initFromJNI(.placeholder, swiftType: self.knownTypes.string)
              ),
              indirectConversion: nil,
              conversionCheck: nil
            )

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType.kind, config: self.config),
              javaType.implementsJavaValue
            else {
              throw JavaTranslationError.unsupportedSwiftType(type)
            }

            let indirectStepType = JNIJavaTypeTranslator.indirectConversionStepSwiftType(
              for: knownType.kind,
              from: knownTypes
            )
            let indirectCheck = JNIJavaTypeTranslator.checkStep(for: knownType.kind, from: knownTypes)

            return NativeParameter(
              parameters: [
                JavaParameter(name: parameterName, type: javaType)
              ],
              conversion: indirectStepType != nil
                ? .labelessAssignmentOfVariable(.placeholder, swiftType: type)
                : .initFromJNI(.placeholder, swiftType: type),
              indirectConversion: indirectStepType.flatMap { .initFromJNI(.placeholder, swiftType: $0) },
              conversionCheck: indirectCheck
            )

          }
        }

        if nominalType.isSwiftJavaWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromSwiftJavaName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(type)
          }

          return NativeParameter(
            parameters: [
              JavaParameter(name: parameterName, type: javaType)
            ],
            conversion: .initializeSwiftJavaWrapper(
              .unwrapOptional(
                .placeholder,
                name: parameterName,
                fatalErrorMessage:
                  "\(parameterName) was null in call to \\(#function), but Swift requires non-optional!"
              ),
              wrapperName: nominalTypeName
            ),
            indirectConversion: nil,
            conversionCheck: nil
          )
        }

        // JExtract classes are passed as the pointer.
        return NativeParameter(
          parameters: [
            JavaParameter(name: parameterName, type: .long)
          ],
          conversion: .pointee(.extractSwiftValue(.placeholder, swiftType: type)),
          indirectConversion: nil,
          conversionCheck: nil
        )

      case .tuple([]):
        return NativeParameter(
          parameters: [
            JavaParameter(name: parameterName, type: .void)
          ],
          conversion: .placeholder,
          indirectConversion: nil,
          conversionCheck: nil
        )

      case .function(let fn):

        // @Sendable is not supported yet as "environment" is later captured inside the closure.
        if fn.isEscaping {
          // Use the protocol infrastructure for escaping closures.
          // This provides full support for optionals, arrays, custom types, async, etc.
          let wrapJavaInterfaceName = "Java\(parentName).\(methodName).\(parameterName)"
          let generator = JavaInterfaceProtocolWrapperGenerator()
          let syntheticFunction = try generator.generateSyntheticClosureFunction(
            functionType: fn,
            wrapJavaInterfaceName: wrapJavaInterfaceName
          )

          return NativeParameter(
            parameters: [
              JavaParameter(
                name: parameterName,
                type: .class(package: javaPackage, name: "\(parentName).\(methodName).\(parameterName)")
              )
            ],
            conversion: .escapingClosureLowering(
              syntheticFunction: syntheticFunction,
              closureName: parameterName
            ),
            indirectConversion: nil,
            conversionCheck: nil
          )
        }

        // Non-escaping closures use the legacy translation
        var parameters = [NativeParameter]()
        for (i, parameter) in fn.parameters.enumerated() {
          let closureParamName = parameter.parameterName ?? "_\(i)"
          let closureParameter = try translateClosureParameter(
            parameter.type,
            parameterName: closureParamName
          )
          parameters.append(closureParameter)
        }

        let result = try translateClosureResult(fn.resultType)

        return NativeParameter(
          parameters: [
            JavaParameter(
              name: parameterName,
              type: .class(package: javaPackage, name: "\(parentName).\(methodName).\(parameterName)")
            )
          ],
          conversion: .closureLowering(
            parameters: parameters,
            result: result
          ),
          indirectConversion: nil,
          conversionCheck: nil
        )

      case .opaque(let proto), .existential(let proto):
        return try translateProtocolParameter(
          protocolType: proto,
          methodName: methodName,
          parameterName: parameterName,
          parentName: parentName
        )

      case .genericParameter:
        if let concreteTy = type.typeIn(genericParameters: genericParameters, genericRequirements: genericRequirements) {
          return try translateProtocolParameter(
            protocolType: concreteTy,
            methodName: methodName,
            parameterName: parameterName,
            parentName: parentName
          )
        }

        throw JavaTranslationError.unsupportedSwiftType(type)

      case .metatype:
        return NativeParameter(
          parameters: [
            JavaParameter(name: parameterName, type: .long)
          ],
          conversion: .extractMetatypeValue(.placeholder),
          indirectConversion: nil,
          conversionCheck: nil
        )

      case .tuple(let elements) where !elements.isEmpty:
        return try translateTupleParameter(
          elements: elements,
          parameterName: parameterName,
          methodName: methodName,
          parentName: parentName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )

      case .tuple, .composite:
        throw JavaTranslationError.unsupportedSwiftType(type)
      }
    }

    func translateTupleParameter(
      elements: [SwiftTupleElement],
      parameterName: String,
      methodName: String,
      parentName: SwiftQualifiedTypeName,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement]
    ) throws -> NativeParameter {
      var allJNIParameters: [JavaParameter] = []
      var elementConversions: [(label: String?, conversion: NativeSwiftConversionStep)] = []

      for (idx, element) in elements.enumerated() {
        let elementParamName = "\(parameterName)_\(idx)"
        let elementNative = try translateParameter(
          type: element.type,
          parameterName: elementParamName,
          methodName: methodName,
          parentName: parentName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )
        allJNIParameters.append(contentsOf: elementNative.parameters)
        elementConversions.append((label: element.label, conversion: elementNative.conversion))
      }

      return NativeParameter(
        parameters: allJNIParameters,
        conversion: .tupleConstruct(elements: elementConversions),
        indirectConversion: nil,
        conversionCheck: nil
      )
    }

    func translateProtocolParameter(
      protocolType: SwiftType,
      methodName: String,
      parameterName: String,
      parentName: SwiftQualifiedTypeName?
    ) throws -> NativeParameter {
      switch protocolType {
      case .nominal(let nominalType):
        return try translateProtocolParameter(
          protocolTypes: [nominalType],
          methodName: methodName,
          parameterName: parameterName,
          parentName: parentName
        )

      case .composite(let types):
        let protocolTypes = try types.map {
          guard let nominalTypeName = $0.asNominalType else {
            throw JavaTranslationError.unsupportedSwiftType($0)
          }
          return nominalTypeName
        }

        return try translateProtocolParameter(
          protocolTypes: protocolTypes,
          methodName: methodName,
          parameterName: parameterName,
          parentName: parentName
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(protocolType)
      }
    }

    private func translateProtocolParameter(
      protocolTypes: [SwiftNominalType],
      methodName: String,
      parameterName: String,
      parentName: SwiftQualifiedTypeName?
    ) throws -> NativeParameter {
      // We allow Java implementations if we are able to generate the needed
      // Swift wrappers for all the protocol types.
      let allowsJavaImplementations = protocolTypes.allSatisfy { protocolType in
        self.protocolWrappers.contains(where: { $0.value.protocolType == protocolType })
      }

      return NativeParameter(
        parameters: [
          JavaParameter(name: parameterName, type: .javaLangObject)
        ],
        conversion: .interfaceToSwiftObject(
          .placeholder,
          swiftWrapperClassName: JNISwift2JavaGenerator.protocolParameterWrapperClassName(
            methodName: methodName,
            parameterName: parameterName,
            parentName: parentName
          ),
          protocolTypes: protocolTypes,
          allowsJavaImplementations: allowsJavaImplementations
        ),
        indirectConversion: nil,
        conversionCheck: nil
      )
    }

    func translateOptionalParameter(
      wrappedType swiftType: SwiftType,
      parameterName: String
    ) throws -> NativeParameter {
      let discriminatorName = "\(parameterName)_discriminator"
      let valueName = "\(parameterName)_value"

      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .foundationDate, .essentialsDate:
            // Handled as wrapped struct
            break

          case .foundationData, .essentialsData:
            // Handled as wrapped struct
            break

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
              javaType.implementsJavaValue
            else {
              self.logger.debug("Known type \(knownType) is not supported for optional parameters, skipping.")
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            return NativeParameter(
              parameters: [
                JavaParameter(name: discriminatorName, type: .byte),
                JavaParameter(name: valueName, type: javaType),
              ],
              conversion: .optionalLowering(
                .initFromJNI(.placeholder, swiftType: swiftType),
                discriminatorName: discriminatorName,
                valueName: valueName
              ),
              indirectConversion: nil,
              conversionCheck: nil
            )
          }
        }

        if nominalType.isSwiftJavaWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromSwiftJavaName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftType)
          }

          return NativeParameter(
            parameters: [
              JavaParameter(name: parameterName, type: javaType)
            ],
            conversion: .optionalMap(.initializeSwiftJavaWrapper(.placeholder, wrapperName: nominalTypeName)),
            indirectConversion: nil,
            conversionCheck: nil
          )
        }

        // Assume JExtract wrapped class
        return NativeParameter(
          parameters: [JavaParameter(name: parameterName, type: .long)],
          conversion: .pointee(
            .optionalChain(
              .extractSwiftValue(
                .placeholder,
                swiftType: swiftType,
                allowNil: true
              )
            )
          ),
          indirectConversion: nil,
          conversionCheck: nil
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func translateOptionalResult(
      wrappedType swiftType: SwiftType,
      methodName: String,
      resultName: String = "result"
    ) throws -> NativeResult {
      let discriminatorName = "\(resultName)_discriminator$"

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
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
              javaType.implementsJavaValue
            else {
              self.logger.debug("Known type \(knownType) is not supported for optional results, skipping.")
              throw JavaTranslationError.unsupportedSwiftType(swiftType)
            }

            // Check if we can fit the value and a discriminator byte in a primitive.
            // so the return JNI value will be (value, discriminator)
            if let nextIntergralTypeWithSpaceForByte = javaType.nextIntergralTypeWithSpaceForByte {
              return NativeResult(
                javaType: nextIntergralTypeWithSpaceForByte.javaType,
                conversion: .getJNIValue(
                  .optionalRaisingWidenIntegerType(
                    .placeholder,
                    resultName: resultName,
                    valueType: javaType,
                    combinedSwiftType: nextIntergralTypeWithSpaceForByte.swiftType,
                    valueSizeInBytes: nextIntergralTypeWithSpaceForByte.valueBytes
                  )
                ),
                outParameters: []
              )
            } else {
              // Use indirect byte array to store discriminator

              return NativeResult(
                javaType: javaType,
                conversion: .optionalRaisingIndirectReturn(
                  .getJNIValue(.placeholder),
                  returnType: javaType,
                  discriminatorParameterName: discriminatorName,
                  placeholderValue: .member(
                    .constant("\(swiftType)"),
                    member: "jniPlaceholderValue"
                  )
                ),
                outParameters: [
                  JavaParameter(name: discriminatorName, type: .array(.byte))
                ]
              )
            }
          }
        }

        guard !nominalType.isSwiftJavaWrapper else {
          // TODO: Should be the same as above
          throw JavaTranslationError.unsupportedSwiftType(swiftType)
        }

        let wrappedValueResult = try translate(
          swiftResult: .init(
            convention: .direct,
            type: swiftType
          ),
          methodName: methodName,
          resultName: resultName + "Wrapped"
        )

        // Assume JExtract imported class
        return NativeResult(
          javaType: wrappedValueResult.javaType,
          conversion: .optionalRaisingIndirectReturn(
            wrappedValueResult.conversion,
            returnType: wrappedValueResult.javaType,
            discriminatorParameterName: discriminatorName,
            placeholderValue: .constant("0")
          ),
          outParameters: [
            JavaParameter(name: discriminatorName, type: .array(.byte))
          ] + wrappedValueResult.outParameters
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func translateClosureResult(
      _ type: SwiftType
    ) throws -> NativeResult {
      switch type {
      case .nominal(let nominal):
        if let knownType = nominal.nominalTypeDecl.knownTypeKind {

          if knownType == .void {
            return NativeResult(
              javaType: .void,
              conversion: .placeholder,
              outParameters: []
            )
          }

          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
            javaType.implementsJavaValue
          else {
            throw JavaTranslationError.unsupportedSwiftType(type)
          }

          // Only support primitives for now.
          return NativeResult(
            javaType: javaType,
            conversion: .initFromJNI(.placeholder, swiftType: type),
            outParameters: []
          )
        }

        // Custom types are not supported yet.
        throw JavaTranslationError.unsupportedSwiftType(type)

      case .tuple([]):
        return NativeResult(
          javaType: .void,
          conversion: .placeholder,
          outParameters: []
        )

      case .function, .metatype, .tuple, .existential, .opaque, .genericParameter, .composite:
        throw JavaTranslationError.unsupportedSwiftType(type)
      }
    }

    func translateClosureParameter(
      _ type: SwiftType,
      parameterName: String
    ) throws -> NativeParameter {
      switch type {
      case .nominal(let nominal):
        if let knownType = nominal.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
            javaType.implementsJavaValue
          else {
            throw JavaTranslationError.unsupportedSwiftType(type)
          }

          // Only support primitives for now.
          return NativeParameter(
            parameters: [
              JavaParameter(name: parameterName, type: javaType)
            ],
            conversion: .getJValue(.placeholder),
            indirectConversion: nil,
            conversionCheck: nil
          )
        }

        // Custom types are not supported yet.
        throw JavaTranslationError.unsupportedSwiftType(type)

      case .function, .metatype, .tuple, .existential, .opaque, .genericParameter, .composite:
        throw JavaTranslationError.unsupportedSwiftType(type)
      }
    }

    func translate(
      swiftResult: SwiftResult,
      methodName: String,
      resultName: String = "result"
    ) throws -> NativeResult {
      switch swiftResult.type {
      case .nominal(let nominalType):
        if let knownType = nominalType.asKnownType {
          switch knownType {
          case .optional(let wrapped):
            return try translateOptionalResult(wrappedType: wrapped, methodName: methodName, resultName: resultName)

          case .array(let elementType):
            return try translateArrayResult(elementType: elementType, resultName: resultName)

          case .dictionary(let keyType, let valueType):
            return try translateDictionaryResult(
              keyType: keyType,
              valueType: valueType,
              resultName: resultName
            )

          case .set(let elementType):
            return try translateSetResult(
              elementType: elementType,
              resultName: resultName
            )

          case .foundationDate, .essentialsDate, .foundationData, .essentialsData:
            // Handled as wrapped struct
            break

          case .foundationUUID, .essentialsUUID:
            return NativeResult(
              javaType: .javaLangString,
              conversion: .getJNIValue(.member(.placeholder, member: "uuidString")),
              outParameters: []
            )

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType.kind, config: self.config),
              javaType.implementsJavaValue
            else {
              throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
            }

            if let indirectReturnType = JNIJavaTypeTranslator.indirectConversionStepSwiftType(
              for: knownType.kind,
              from: knownTypes
            ) {
              return NativeResult(
                javaType: javaType,
                conversion: .getJNIValue(.labelessInitializer(.placeholder, swiftType: indirectReturnType)),
                outParameters: []
              )
            } else {
              return NativeResult(
                javaType: javaType,
                conversion: .getJNIValue(.placeholder),
                outParameters: []
              )
            }
          }
        }

        if nominalType.isSwiftJavaWrapper {
          throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
        }

        if nominalType.nominalTypeDecl.isGeneric {
          return NativeResult(
            javaType: .void,
            conversion: .genericValueIndirectReturn(
              .getJNIValue(.allocateSwiftValue(.placeholder, name: resultName, swiftType: swiftResult.type)),
              swiftFunctionResultType: swiftResult.type,
              outArgumentName: resultName + "Out"
            ),
            outParameters: [.init(name: resultName + "Out", type: ._OutSwiftGenericInstance)]
          )
        } else {
          return NativeResult(
            javaType: .long,
            conversion: .getJNIValue(.allocateSwiftValue(.placeholder, name: resultName, swiftType: swiftResult.type)),
            outParameters: []
          )
        }

      case .tuple([]):
        return NativeResult(
          javaType: .void,
          conversion: .placeholder,
          outParameters: []
        )

      case .tuple(let elements) where !elements.isEmpty:
        return try translateTupleResult(methodName: methodName, elements: elements, resultName: resultName)

      case .metatype, .tuple, .function, .existential, .opaque, .genericParameter, .composite:
        throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
      }
    }

    func translateTupleResult(
      methodName: String,
      elements: [SwiftTupleElement],
      resultName: String
    ) throws -> NativeResult {
      var outParameters: [JavaParameter] = []
      var destructureElements: [(index: Int, label: String?, conversion: NativeSwiftConversionStep, outParamName: String, javaType: JavaType)] = []

      for (idx, element) in elements.enumerated() {
        let outParamName = "\(resultName)_\(idx)$"

        // Get the JNI type for this element
        let elementResult = try translate(
          swiftResult: .init(convention: .indirect, type: element.type),
          methodName: methodName,
          resultName: outParamName
        )

        // FIXME: More accurate determination of whether the result is direct or indirect
        if elementResult.outParameters.isEmpty {
          // Convert direct result to indirect result
          outParameters.append(
            JavaParameter(name: outParamName, type: .array(elementResult.javaType))
          )
        } else {
          outParameters.append(contentsOf: elementResult.outParameters)
        }

        destructureElements.append(
          (
            index: idx,
            label: element.label,
            conversion: elementResult.conversion,
            outParamName: outParamName,
            javaType: elementResult.javaType
          )
        )
      }

      return NativeResult(
        javaType: .void,
        conversion: .tupleDestructure(elements: destructureElements),
        outParameters: outParameters
      )
    }

    func translateArrayResult(
      elementType: SwiftType,
      resultName: String
    ) throws -> NativeResult {
      switch elementType {
      case .nominal(let nominalType) where nominalType.nominalTypeDecl.knownTypeKind == .array:
        guard let fullKnownType = nominalType.asKnownType else {
          throw JavaTranslationError.unsupportedSwiftType(known: .array(elementType))
        }

        guard case .array(let innerElement) = fullKnownType else {
          throw JavaTranslationError.unsupportedSwiftType(known: .array(elementType))
        }

        let innerResult = try translateArrayResult(elementType: innerElement, resultName: resultName)
        return NativeResult(
          javaType: .array(innerResult.javaType),
          conversion: .getJNIValue(.placeholder),
          outParameters: []
        )

      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
            javaType.implementsJavaValue
          else {
            throw JavaTranslationError.unsupportedSwiftType(known: .array(elementType))
          }

          return NativeResult(
            javaType: .array(javaType),
            conversion: .getJNIValue(.placeholder),
            outParameters: []
          )
        }

        guard !nominalType.isSwiftJavaWrapper else {
          throw JavaTranslationError.unsupportedSwiftType(known: .array(elementType))
        }

        // Assume JExtract imported class
        return NativeResult(
          javaType: .array(.long),
          conversion:
            .getJNIValue(
              .method(
                .placeholder,
                function: "map",
                arguments: [
                  (
                    nil,
                    .closure(
                      args: ["object$"],
                      body: .allocateSwiftValue(.constant("object$"), name: "object$", swiftType: elementType)
                    )
                  )
                ]
              )
            ),
          outParameters: []
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(known: .array(elementType))
      }
    }

    func translateArrayParameter(
      elementType: SwiftType,
      parameterName: String
    ) throws -> NativeParameter {
      switch elementType {
      case .nominal(let nominalType) where nominalType.nominalTypeDecl.knownTypeKind == .array:
        guard let fullKnownType = nominalType.asKnownType else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }

        guard case .array(let innerElement) = fullKnownType else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }

        let innerParam = try translateArrayParameter(elementType: innerElement, parameterName: parameterName)
        guard case .concrete(let innerJavaType) = innerParam.parameters.first?.type else {
          throw JavaTranslationError.unsupportedSwiftType(elementType)
        }
        return NativeParameter(
          parameters: [
            JavaParameter(name: parameterName, type: .array(innerJavaType))
          ],
          conversion: .initFromJNI(.placeholder, swiftType: knownTypes.arraySugar(elementType)),
          indirectConversion: nil,
          conversionCheck: nil
        )

      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
            javaType.implementsJavaValue
          else {
            throw JavaTranslationError.unsupportedSwiftType(elementType)
          }

          return NativeParameter(
            parameters: [
              JavaParameter(name: parameterName, type: .array(javaType))
            ],
            conversion: .initFromJNI(.placeholder, swiftType: knownTypes.arraySugar(elementType)),
            indirectConversion: nil,
            conversionCheck: nil
          )
        }

        guard !nominalType.isSwiftJavaWrapper else {
          throw JavaTranslationError.unsupportedSwiftType(knownTypes.arraySugar(elementType))
        }

        // Assume JExtract wrapped class
        return NativeParameter(
          parameters: [JavaParameter(name: parameterName, type: .array(.long))],
          conversion: .method(
            .initFromJNI(.placeholder, swiftType: knownTypes.arraySugar(self.knownTypes.int64)),
            function: "map",
            arguments: [
              (
                nil,
                .closure(
                  args: ["pointer$"],
                  body: .pointee(
                    .extractSwiftValue(
                      .constant("pointer$"),
                      swiftType: elementType,
                      allowNil: false,
                      convertLongFromJNI: false
                    )
                  )
                )
              )
            ]
          ),
          indirectConversion: nil,
          conversionCheck: nil
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(elementType)
      }
    }

    func translateDictionaryParameter(
      keyType: SwiftType,
      valueType: SwiftType,
      parameterName: String
    ) throws -> NativeParameter {
      NativeParameter(
        parameters: [
          JavaParameter(name: parameterName, type: .long)
        ],
        conversion: .initFromJNI(.placeholder, swiftType: knownTypes.dictionarySugar(keyType, valueType)),
        indirectConversion: nil,
        conversionCheck: nil
      )
    }

    func translateDictionaryResult(
      keyType: SwiftType,
      valueType: SwiftType,
      resultName: String
    ) throws -> NativeResult {
      NativeResult(
        javaType: .long,
        conversion: .method(
          .placeholder,
          function: "dictionaryGetJNIValue",
          arguments: [("in", .constant("environment"))]
        ),
        outParameters: []
      )
    }

    func translateSetParameter(
      elementType: SwiftType,
      parameterName: String
    ) throws -> NativeParameter {
      NativeParameter(
        parameters: [
          JavaParameter(name: parameterName, type: .long)
        ],
        conversion: .initFromJNI(.placeholder, swiftType: knownTypes.set(elementType)),
        indirectConversion: nil,
        conversionCheck: nil
      )
    }

    func translateSetResult(
      elementType: SwiftType,
      resultName: String
    ) throws -> NativeResult {
      NativeResult(
        javaType: .long,
        conversion: .method(
          .placeholder,
          function: "setGetJNIValue",
          arguments: [("in", .constant("environment"))]
        ),
        outParameters: []
      )
    }
  }

  struct NativeFunctionSignature {
    let selfParameter: NativeParameter?
    var selfTypeParameter: NativeParameter?
    var parameters: [NativeParameter]
    var result: NativeResult
  }

  struct NativeParameter {
    /// One Swift parameter can be lowered to multiple parameters.
    /// E.g. 'Optional<Int>' as (descriptor, value) pair.
    var parameters: [JavaParameter]

    /// Represents how to convert the JNI parameter to a Swift parameter
    let conversion: NativeSwiftConversionStep

    /// Represents swift type for conversion checks. This will introduce a new name$indirect variable used in required checks.
    /// e.g Int64 for Int overflow check on 32-bit platforms
    let indirectConversion: NativeSwiftConversionStep?

    /// Represents check operations executed in if/guard conditional block for check during conversion
    let conversionCheck: NativeSwiftConversionCheck?
  }

  struct NativeResult {
    var javaType: JavaType
    var conversion: NativeSwiftConversionStep

    /// Out parameters for populating the indirect return values.
    var outParameters: [JavaParameter]

    init(javaType: JavaType, conversion: NativeSwiftConversionStep, outParameters: [JavaParameter]) {
      self.javaType = javaType
      self.conversion = conversion.localRefOutermostJNIValue()
      self.outParameters = outParameters
    }
  }

  /// Describes how to convert values between Java types and Swift through JNI
  enum NativeSwiftConversionStep {
    /// The value being converted
    case placeholder

    case constant(String)

    /// `input_component`
    case combinedName(component: String)

    /// `value.getJNIValue(in:)`
    indirect case getJNIValue(NativeSwiftConversionStep)

    /// `value.getJNILocalRefValue(in:)` — used only in return positions of
    /// @_cdecl functions to ensure the local ref survives ARC destruction.
    indirect case getJNILocalRefValue(NativeSwiftConversionStep)

    /// `value.getJValue(in:)`
    indirect case getJValue(NativeSwiftConversionStep)

    /// `SwiftType(from: value, in: environment)`
    indirect case initFromJNI(NativeSwiftConversionStep, swiftType: SwiftType)

    indirect case interfaceToSwiftObject(
      NativeSwiftConversionStep,
      swiftWrapperClassName: String,
      protocolTypes: [SwiftNominalType],
      allowsJavaImplementations: Bool
    )

    indirect case extractSwiftProtocolValue(
      NativeSwiftConversionStep,
      typeMetadataVariableName: NativeSwiftConversionStep,
      protocolTypes: [SwiftNominalType]
    )

    /// Extracts a swift type at a pointer given by a long.
    indirect case extractSwiftValue(
      NativeSwiftConversionStep,
      swiftType: SwiftType,
      allowNil: Bool = false,
      convertLongFromJNI: Bool = true
    )

    indirect case extractMetatypeValue(NativeSwiftConversionStep)

    /// Allocate memory for a Swift value and outputs the pointer
    indirect case allocateSwiftValue(NativeSwiftConversionStep, name: String, swiftType: SwiftType)

    /// The thing to which the pointer typed, which is the `pointee` property
    /// of the `Unsafe(Mutable)Pointer` types in Swift.
    indirect case pointee(NativeSwiftConversionStep)

    indirect case closureLowering(parameters: [NativeParameter], result: NativeResult)

    /// Escaping closure lowering using the protocol infrastructure.
    /// This uses UpcallConversionStep for full support of optionals, arrays, custom types, etc.
    indirect case escapingClosureLowering(
      syntheticFunction: SyntheticClosureFunction,
      closureName: String
    )

    indirect case initializeSwiftJavaWrapper(NativeSwiftConversionStep, wrapperName: String)

    indirect case optionalLowering(NativeSwiftConversionStep, discriminatorName: String, valueName: String)

    indirect case optionalChain(NativeSwiftConversionStep)

    indirect case optionalRaisingWidenIntegerType(
      NativeSwiftConversionStep,
      resultName: String,
      valueType: JavaType,
      combinedSwiftType: SwiftKnownTypeDeclKind,
      valueSizeInBytes: Int
    )

    indirect case optionalRaisingIndirectReturn(
      NativeSwiftConversionStep,
      returnType: JavaType,
      discriminatorParameterName: String,
      placeholderValue: NativeSwiftConversionStep
    )

    indirect case genericValueIndirectReturn(
      NativeSwiftConversionStep,
      swiftFunctionResultType: SwiftType,
      outArgumentName: String
    )

    indirect case method(
      NativeSwiftConversionStep,
      function: String,
      arguments: [(String?, NativeSwiftConversionStep)] = []
    )

    indirect case member(NativeSwiftConversionStep, member: String)

    indirect case optionalMap(NativeSwiftConversionStep)

    indirect case unwrapOptional(NativeSwiftConversionStep, name: String, fatalErrorMessage: String)

    indirect case asyncCompleteFuture(
      swiftFunctionResultType: SwiftType,
      nativeFunctionSignature: NativeFunctionSignature,
      isThrowing: Bool,
      completeMethodID: String,
      completeExceptionallyMethodID: String
    )

    /// `{ (args) -> return body }`
    indirect case closure(args: [String] = [], body: NativeSwiftConversionStep)

    indirect case labelessAssignmentOfVariable(NativeSwiftConversionStep, swiftType: SwiftType)

    indirect case aggregate(variable: String, [NativeSwiftConversionStep])

    indirect case replacingPlaceholder(NativeSwiftConversionStep, placeholder: NativeSwiftConversionStep)

    /// `SwiftType(inner)`
    indirect case labelessInitializer(NativeSwiftConversionStep, swiftType: SwiftType)

    /// Converts a jbyteArray to UnsafeRawBufferPointer or UnsafeMutableRawBufferPointer via GetByteArrayElements
    indirect case jniByteArrayToUnsafeRawBufferPointer(NativeSwiftConversionStep, name: String, mutable: Bool)

    /// Constructs a Swift tuple from individually-converted elements.
    /// E.g. `(label0: conv0, conv1)` for `(label0: Int, String)`
    indirect case tupleConstruct(elements: [(label: String?, conversion: NativeSwiftConversionStep)])

    /// Destructures a Swift tuple result and writes each element to an out-parameter.
    indirect case tupleDestructure(elements: [(index: Int, label: String?, conversion: NativeSwiftConversionStep, outParamName: String, javaType: JavaType)])

    /// Promotes the outermost `.getJNIValue` to `.getJNILocalRefValue`.
    /// Used for `@_cdecl` return positions to ensure the local ref survives
    /// ARC destruction of temporary `JavaObject`s.
    func localRefOutermostJNIValue() -> NativeSwiftConversionStep {
      switch self {
      case .getJNIValue(let inner):
        return .getJNILocalRefValue(inner)
      default:
        return self
      }
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

      case .getJNIValue(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).getJNIValue(in: environment)"

      case .getJNILocalRefValue(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).getJNILocalRefValue(in: environment)"

      case .getJValue(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).getJValue(in: environment)"

      case .initFromJNI(let inner, let swiftType):
        let inner = inner.render(&printer, placeholder)
        return "\(swiftType)(fromJNI: \(inner), in: environment)"

      case .interfaceToSwiftObject(
        let inner,
        let swiftWrapperClassName,
        let protocolTypes,
        let allowsJavaImplementations
      ):
        let inner = inner.render(&printer, placeholder)
        let variableName = "\(inner)swiftObject$"
        let existentialType = SwiftKitPrinting.renderExistentialType(protocolTypes)
        printer.print("let \(variableName): \(existentialType)")

        func printStandardJExtractBlock(_ printer: inout CodePrinter) {
          let pointerVariableName = "\(inner)pointer$"
          let typeMetadataVariableName = "\(inner)typeMetadata$"
          printer.print(
            """
            let \(pointerVariableName) = environment.interface.CallLongMethodA(environment, \(inner), _JNIMethodIDCache.JNISwiftInstance.memoryAddress, [])
            let \(typeMetadataVariableName) = environment.interface.CallLongMethodA(environment, \(inner), _JNIMethodIDCache.JNISwiftInstance.typeMetadataAddress, [])
            """
          )
          let existentialName = NativeSwiftConversionStep.extractSwiftProtocolValue(
            .constant(pointerVariableName),
            typeMetadataVariableName: .constant(typeMetadataVariableName),
            protocolTypes: protocolTypes
          ).render(&printer, placeholder)

          printer.print("\(variableName) = \(existentialName)")
        }

        // If this protocol type supports being implemented by the user
        // then we will check whether it is a JNI SwiftInstance type
        // or if its a custom class implementing the interface.
        if allowsJavaImplementations {
          printer.printBraceBlock(
            "if environment.interface.IsInstanceOf(environment, \(inner), _JNIMethodIDCache.JNISwiftInstance.class) != 0"
          ) { printer in
            printStandardJExtractBlock(&printer)
          }
          printer.printBraceBlock("else") { printer in
            let arguments = protocolTypes.map { protocolType in
              let nominalTypeDecl = protocolType.nominalTypeDecl
              return
                "\(nominalTypeDecl.javaInterfaceVariableName): \(nominalTypeDecl.javaInterfaceName)(javaThis: \(inner)!, environment: environment)"
            }
            printer.print("\(variableName) = \(swiftWrapperClassName)(\(arguments.joined(separator: ", ")))")
          }
        } else {
          printStandardJExtractBlock(&printer)
        }

        return variableName

      case .extractSwiftProtocolValue(let inner, let typeMetadataVariableName, let protocolTypes):
        let inner = inner.render(&printer, placeholder)
        let typeMetadataVariableName = typeMetadataVariableName.render(&printer, placeholder)
        let existentialName = "\(inner)Existential$"

        let existentialType = SwiftKitPrinting.renderExistentialType(protocolTypes)

        // TODO: Remove the _openExistential when we decide to only support language mode v6+
        printer.print(
          """
          guard let \(inner)TypeMetadataPointer$ = UnsafeRawPointer(bitPattern: Int(Int64(fromJNI: \(typeMetadataVariableName), in: environment))) else {
            fatalError("\(typeMetadataVariableName) memory address was null")
          }
          let \(inner)DynamicType$: Any.Type = unsafeBitCast(\(inner)TypeMetadataPointer$, to: Any.Type.self)
          guard let \(inner)RawPointer$ = UnsafeMutableRawPointer(bitPattern: Int(Int64(fromJNI: \(inner), in: environment))) else {
            fatalError("\(inner) memory address was null")
          }
          #if hasFeature(ImplicitOpenExistentials)
          let \(existentialName) = \(inner)RawPointer$.load(as: \(inner)DynamicType$) as! \(existentialType)
          #else
          func \(inner)DoLoad<Ty>(_ ty: Ty.Type) -> \(existentialType) {
            \(inner)RawPointer$.load(as: ty) as! \(existentialType)
          }
          let \(existentialName) = _openExistential(\(inner)DynamicType$, do: \(inner)DoLoad)
          #endif
          """
        )
        return existentialName

      case .extractSwiftValue(let inner, let swiftType, let allowNil, let convertLongFromJNI):
        let inner = inner.render(&printer, placeholder)
        let pointerName = "\(inner)$"
        if !allowNil {
          printer.print(#"assert(\#(inner) != 0, "\#(inner) memory address was null")"#)
        }
        if convertLongFromJNI {
          printer.print("let \(inner)Bits$ = Int(Int64(fromJNI: \(inner), in: environment))")
        } else {
          printer.print("let \(inner)Bits$ = Int(\(inner))")
        }
        printer.print("let \(pointerName) = UnsafeMutablePointer<\(swiftType)>(bitPattern: \(inner)Bits$)")
        if !allowNil {
          printer.print(
            """
            guard let \(pointerName) else {
              fatalError("\(inner) memory address was null in call to \\(#function)!")
            }
            """
          )
        }
        return pointerName

      case .extractMetatypeValue(let inner):
        let inner = inner.render(&printer, placeholder)
        let pointerName = "\(inner)$"
        printer.print(
          """
          let \(inner)Bits$ = Int(Int64(fromJNI: \(inner), in: environment))
          guard let \(pointerName) = UnsafeRawPointer(bitPattern: \(inner)Bits$) else {
            fatalError("\(inner) metadata address was null")
          }
          """
        )
        return "unsafeBitCast(\(pointerName), to: Any.Type.self)"

      case .allocateSwiftValue(let inner, let name, let swiftType):
        let inner = inner.render(&printer, placeholder)
        let pointerName = "\(name)$"
        let bitsName = "\(name)Bits$"
        printer.print(
          """
          let \(pointerName) = UnsafeMutablePointer<\(swiftType)>.allocate(capacity: 1)
          \(pointerName).initialize(to: \(inner))
          let \(bitsName) = Int64(Int(bitPattern: \(pointerName)))
          """
        )
        return bitsName

      case .pointee(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).pointee"

      case .closureLowering(let parameters, let nativeResult):
        var printer = CodePrinter()

        let methodSignature = MethodSignature(
          resultType: nativeResult.javaType,
          parameterTypes: parameters.flatMap {
            $0.parameters.map { parameter in
              guard case .concrete(let type) = parameter.type else {
                fatalError("Closures do not support Java generics")
              }
              return type
            }
          }
        )

        let names = parameters.flatMap { $0.parameters.map(\.name) }
        let closureParameters = !parameters.isEmpty ? "\(names.joined(separator: ", ")) in" : ""
        printer.print("{ \(closureParameters)")
        printer.indent()

        // TODO: Add support for types that are lowered to multiple parameters in closures
        let arguments = parameters.map {
          $0.conversion.render(&printer, $0.parameters.first!.name)
        }

        printer.print(
          """
          let class$ = environment.interface.GetObjectClass(environment, \(placeholder))
          let methodID$ = environment.interface.GetMethodID(environment, class$, "apply", "\(methodSignature.mangledName)")!
          environment.interface.DeleteLocalRef(environment, class$)
          let arguments$: [jvalue] = [\(arguments.joined(separator: ", "))]
          """
        )

        let upcall =
          "environment.interface.\(nativeResult.javaType.jniCallMethodAName)(environment, \(placeholder), methodID$, arguments$)"
        let result = nativeResult.conversion.render(&printer, upcall)

        if nativeResult.javaType.isVoid {
          printer.print(result)
        } else {
          printer.print("return \(result)")
        }

        printer.outdent()
        printer.print("}")

        return printer.finalize()

      case .escapingClosureLowering(let syntheticFunction, let closureName):
        var printer = CodePrinter()

        let fn = syntheticFunction.functionType
        let parameterNames = fn.parameters.enumerated().map { idx, param in
          param.parameterName ?? "_\(idx)"
        }
        let closureParameters = parameterNames.joined(separator: ", ")
        let isVoid = fn.resultType == .tuple([])

        // Build upcall arguments using UpcallConversionStep conversions
        var upcallArguments: [String] = []
        for (idx, conversion) in syntheticFunction.parameterConversions.enumerated() {
          var argPrinter = CodePrinter()
          let paramName = parameterNames[idx]
          let converted = conversion.render(&argPrinter, paramName)
          upcallArguments.append(converted)
        }

        // Build result conversion
        // Note: The Java interface is synchronous even for async closures.
        // The async nature is on the Swift side, inferred from the expected type.
        var resultPrinter = CodePrinter()
        let upcallExpr = "javaInterface$.apply(\(upcallArguments.joined(separator: ", ")))"
        let resultConverted = syntheticFunction.resultConversion.render(&resultPrinter, upcallExpr)
        let resultPrefix = resultPrinter.finalize()

        // Note: async is part of the closure TYPE, not the closure literal syntax.
        // For closures without parameters, we can omit "in" entirely.
        let closureHeader =
          fn.parameters.isEmpty
          ? "{"
          : "{ \(closureParameters) in"

        printer.print(
          """
          {
            guard let \(placeholder) else {
              fatalError(\"\(placeholder) is null\")
            }

            let closureContext_\(closureName)$ = JavaObjectHolder(object: \(placeholder), environment: environment)
            
            return \(closureHeader)
              guard let env$ = try? JavaVirtualMachine.shared().environment() else {
                fatalError(\"Failed to get JNI environment for escaping closure call\")
              }

              let javaInterface$ = \(syntheticFunction.wrapJavaInterfaceName)(javaThis: closureContext_\(closureName)$.object!, environment: env$)
              \(resultPrefix)\(isVoid ? resultConverted : "return \(resultConverted)")
            }
          }()
          """
        )

        return printer.finalize()

      case .initializeSwiftJavaWrapper(let inner, let wrapperName):
        let inner = inner.render(&printer, placeholder)
        return "\(wrapperName)(javaThis: \(inner), environment: environment)"

      case .optionalLowering(let valueConversion, let discriminatorName, let valueName):
        let value = valueConversion.render(&printer, valueName)
        return "\(discriminatorName) == 1 ? \(value) : nil"

      case .optionalChain(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner)?"

      case .optionalRaisingWidenIntegerType(
        let inner,
        let resultName,
        let valueType,
        let combinedSwiftType,
        let valueSizeInBytes
      ):
        let inner = inner.render(&printer, placeholder)
        let value = valueType == .boolean ? "$0 ? 1 : 0" : "$0"
        let combinedSwiftTypeName = combinedSwiftType.moduleAndName.name
        printer.print(
          """
          let \(resultName)_value$ = \(inner).map {
            \(combinedSwiftTypeName)(\(value)) << \(valueSizeInBytes * 8) | \(combinedSwiftTypeName)(1)
          } ?? 0
          """
        )
        return "\(resultName)_value$"

      case .optionalRaisingIndirectReturn(
        let inner,
        let returnType,
        let discriminatorParameterName,
        let placeholderValue
      ):
        if !returnType.isVoid {
          printer.print("let result$: \(returnType.jniTypeName)")
        }
        printer.printBraceBlock("if let innerResult$ = \(placeholder)") { printer in
          let inner = inner.render(&printer, "innerResult$")
          if !returnType.isVoid {
            printer.print("result$ = \(inner)")
          }
          printer.print(
            """
            var flag$ = Int8(1)
            environment.interface.SetByteArrayRegion(environment, \(discriminatorParameterName), 0, 1, &flag$)
            """
          )
        }
        printer.printBraceBlock("else") { printer in
          let placeholderValue = placeholderValue.render(&printer, placeholder)
          if !returnType.isVoid {
            printer.print("result$ = \(placeholderValue)")
          }
          printer.print(
            """
            var flag$ = Int8(0)
            environment.interface.SetByteArrayRegion(environment, \(discriminatorParameterName), 0, 1, &flag$)
            """
          )
        }
        if !returnType.isVoid {
          return "result$"
        } else {
          return ""
        }

      case .genericValueIndirectReturn(let inner, let swiftFunctionResultType, let outArgumentName):
        let inner = inner.render(&printer, placeholder)
        printer.printBraceBlock("do") { printer in
          printer.print(
            """
            environment.interface.SetLongField(environment, \(outArgumentName), _JNIMethodIDCache._OutSwiftGenericInstance.selfPointer, \(inner))
            let metadataPointer = unsafeBitCast(\(swiftFunctionResultType).self, to: UnsafeRawPointer.self)
            let metadataPointerBits$ = Int64(Int(bitPattern: metadataPointer))
            environment.interface.SetLongField(environment, \(outArgumentName), _JNIMethodIDCache._OutSwiftGenericInstance.selfTypePointer, metadataPointerBits$.getJNIValue(in: environment))
            """
          )
        }
        return ""

      case .method(let inner, let methodName, let arguments):
        let inner = inner.render(&printer, placeholder)
        let args = arguments.map { name, value in
          let value = value.render(&printer, placeholder)
          if let name {
            return "\(name): \(value)"
          } else {
            return value
          }
        }
        let argsStr = args.joined(separator: ", ")
        return "\(inner).\(methodName)(\(argsStr))"

      case .member(let inner, let member):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).\(member)"

      case .optionalMap(let inner):
        var printer = CodePrinter()
        printer.printBraceBlock("\(placeholder).map") { printer in
          let inner = inner.render(&printer, "$0")
          printer.print("return \(inner)")
        }
        return printer.finalize()

      case .unwrapOptional(let inner, let name, let fatalErrorMessage):
        let unwrappedName = "\(name)_unwrapped$"
        let inner = inner.render(&printer, placeholder)
        printer.print(
          """
          guard let \(unwrappedName) = \(inner) else {
            fatalError("\(fatalErrorMessage)")
          }
          """
        )
        return unwrappedName

      case .asyncCompleteFuture(
        let swiftFunctionResultType,
        let nativeFunctionSignature,
        let isThrowing,
        let completeMethodID,
        let completeExceptionallyMethodID
      ):
        var globalRefs: [String] = ["globalFuture"]

        // Global ref all indirect returns
        for outParameter in nativeFunctionSignature.result.outParameters {
          printer.print(
            "let \(outParameter.name) = environment.interface.NewGlobalRef(environment, \(outParameter.name))"
          )
          globalRefs.append(outParameter.name)
        }

        // We also need to global ref any objects passed in
        for parameter in nativeFunctionSignature.parameters.flatMap(\.parameters) where !parameter.type.isPrimitive {
          printer.print("let \(parameter.name) = environment.interface.NewGlobalRef(environment, \(parameter.name))")
          globalRefs.append(parameter.name)
        }

        printer.print(
          """
          let globalFuture = environment.interface.NewGlobalRef(environment, result_future)
          """
        )

        printer.print("struct _SwiftJavaUncheckedSendableBox<T>: @unchecked Sendable { let value: T }")
        for globalRef in globalRefs {
          printer.print("let \(globalRef)_sendable$ = _SwiftJavaUncheckedSendableBox(value: \(globalRef))")
        }
        if let selfParameter = nativeFunctionSignature.selfParameter {
          for parameter in selfParameter.parameters {
            printer.print("let \(parameter.name)$sendable$ = _SwiftJavaUncheckedSendableBox(value: \(parameter.name)$)")
          }
        }
        if let selfTypeParameter = nativeFunctionSignature.selfTypeParameter {
          for parameter in selfTypeParameter.parameters {
            printer.print("let \(parameter.name)$sendable$ = _SwiftJavaUncheckedSendableBox(value: \(parameter.name)$)")
          }
        }

        func printDo(printer: inout CodePrinter) {
          // Make sure try/await are printed when necessary and avoid duplicate, or wrong-order, keywords (which would cause warnings)
          let placeholderWithoutTry =
            if placeholder.hasPrefix("try ") {
              String(placeholder.dropFirst("try ".count))
            } else {
              placeholder
            }

          let tryAwaitString: String =
            if isThrowing {
              "try await"
            } else {
              "await"
            }
          if swiftFunctionResultType.isVoid {
            printer.print("\(tryAwaitString) \(placeholderWithoutTry)")
            printer.print("environment = try! JavaVirtualMachine.shared().environment()")
            printer.print(
              "_ = environment.interface.CallBooleanMethodA(environment, globalFuture, \(completeMethodID), [jvalue(l: nil)])"
            )
          } else {
            printer.print("let swiftResult$ = \(tryAwaitString) \(placeholderWithoutTry)")
            printer.print("environment = try! JavaVirtualMachine.shared().environment()")
            let inner = nativeFunctionSignature.result.conversion.render(&printer, "swiftResult$")
            let result: String
            if nativeFunctionSignature.result.javaType.requiresBoxing {
              printer.print(
                "let boxedResult$ = SwiftJavaRuntimeSupport._JNIBoxedConversions.box(\(inner), in: environment)"
              )
              result = "boxedResult$"
            } else {
              result = inner
            }

            printer.print(
              "_ = environment.interface.CallBooleanMethodA(environment, globalFuture, \(completeMethodID), [jvalue(l: \(result))])"
            )
          }
        }

        func printTaskBody(printer: inout CodePrinter) {
          for globalRef in globalRefs {
            printer.print("let \(globalRef) = \(globalRef)_sendable$.value")
          }
          if let selfParameter = nativeFunctionSignature.selfParameter {
            for parameter in selfParameter.parameters {
              printer.print("let \(parameter.name)$ = \(parameter.name)$sendable$.value")
            }
          }
          if let selfTypeParameter = nativeFunctionSignature.selfTypeParameter {
            for parameter in selfTypeParameter.parameters {
              printer.print("let \(parameter.name)$ = \(parameter.name)$sendable$.value")
            }
          }
          printer.printBraceBlock("defer") { printer in
            // Defer might on any thread, so we need to attach environment.
            printer.print("let deferEnvironment = try! JavaVirtualMachine.shared().environment()")
            for globalRef in globalRefs {
              printer.print("deferEnvironment.interface.DeleteGlobalRef(deferEnvironment, \(globalRef))")
            }
          }
          if isThrowing {
            printer.printBraceBlock("do") { printer in
              printDo(printer: &printer)
            }
            printer.printBraceBlock("catch") { printer in
              // We might not be on the same thread after the suspension, so we need to attach the thread again.
              printer.print(
                """
                let catchEnvironment = try! JavaVirtualMachine.shared().environment()
                let exception = catchEnvironment.interface.NewObjectA(catchEnvironment, _JNIMethodIDCache.Exception.class, _JNIMethodIDCache.Exception.constructWithMessage, [String(describing: error).getJValue(in: catchEnvironment)])
                _ = catchEnvironment.interface.CallBooleanMethodA(catchEnvironment, globalFuture, \(completeExceptionallyMethodID), [jvalue(l: exception)])
                """
              )
            }
          } else {
            printDo(printer: &printer)
          }
        }

        printer.print("var task: Task<Void, Never>? = nil")
        printer.printHashIfBlock("swift(>=6.2)") { printer in
          printer.printBraceBlock("if #available(macOS 26.0, iOS 26.0, watchOS 26.0, tvOS 26.0, *)") { printer in
            printer.printBraceBlock("task = Task.immediate") { printer in
              // Even immediate tasks are a sending closure in Swift 6.2+, so reattach instead of capturing the caller's environment directly.
              printer.print("var environment = try! JavaVirtualMachine.shared().environment()")
              printTaskBody(printer: &printer)
            }
          }
        }

        printer.printBraceBlock("if task == nil") { printer in
          printer.printBraceBlock("task = Task") { printer in
            // We can be on any thread, so we need to attach the thread.
            printer.print("var environment = try! JavaVirtualMachine.shared().environment()")
            printTaskBody(printer: &printer)
          }
        }

        return ""

      case .closure(let args, let body):
        var printer = CodePrinter()
        printer.printBraceBlock("", parameters: args) { printer in
          let body = body.render(&printer, placeholder)
          if !body.isEmpty {
            printer.print("return \(body)")
          }
        }
        return printer.finalize()

      case .labelessAssignmentOfVariable(let name, let swiftType):
        return "\(swiftType)(\(JNISwift2JavaGenerator.indirectVariableName(for: name.render(&printer, placeholder))))"

      case .aggregate(let variable, let steps):
        precondition(!steps.isEmpty, "Aggregate must contain steps")
        printer.print("let \(variable) = \(placeholder)")
        let steps = steps.map {
          $0.render(&printer, variable)
        }
        return steps.last!

      case .replacingPlaceholder(let inner, let newPlaceholder):
        let newPlaceholder = newPlaceholder.render(&printer, placeholder)
        return inner.render(&printer, newPlaceholder)

      case .labelessInitializer(let inner, let swiftType):
        let inner = inner.render(&printer, placeholder)
        return "\(swiftType)(\(inner))"

      case .jniByteArrayToUnsafeRawBufferPointer(let inner, let name, let mutable):
        let inner = inner.render(&printer, placeholder)
        let countVar = "\(name)$count"
        let ptrVar = "\(name)$ptr"
        let rbpVar = "\(name)$rbp"
        let bufferPointerType = mutable ? "UnsafeMutableRawBufferPointer" : "UnsafeRawBufferPointer"
        let releaseMode = mutable ? "0" : "jint(JNI_ABORT)"
        printer.print(
          """
          let \(countVar) = Int(environment.interface.GetArrayLength(environment, \(inner)))
          let \(ptrVar) = environment.interface.GetByteArrayElements(environment, \(inner), nil)!
          defer { environment.interface.ReleaseByteArrayElements(environment, \(inner), \(ptrVar), \(releaseMode)) }
          let \(rbpVar) = \(bufferPointerType)(start: \(ptrVar), count: \(countVar))
          """
        )
        return rbpVar

      case .tupleConstruct(let elements):
        let parts = elements.enumerated().map { idx, element in
          let converted = element.conversion.render(&printer, "\(placeholder)_\(idx)")
          if let label = element.label {
            return "\(label): \(converted)"
          } else {
            return converted
          }
        }
        return "(\(parts.joined(separator: ", ")))"

      case .tupleDestructure(let elements):
        let tupleVar = "tupleResult$"
        printer.print("let \(tupleVar) = \(placeholder)")
        for element in elements {
          let accessor = element.label ?? "\(element.index)"
          let converted = element.conversion.render(&printer, "\(tupleVar).\(accessor)")
          switch element.javaType {
          case .void: break
          case .boolean, .byte, .char, .short, .int, .long, .float, .double:
            let setMethodName = element.javaType.jniSetArrayRegionMethodName
            printer.print("var element_\(element.index)_jni$ = \(converted)")
            printer.print(
              "environment.interface.\(setMethodName)(environment, \(element.outParamName), 0, 1, &element_\(element.index)_jni$)"
            )
          case .class, .array:
            printer.print("let element_\(element.index)_jni$ = \(converted)")
            printer.print(
              "environment.interface.SetObjectArrayElement(environment, \(element.outParamName), 0, element_\(element.index)_jni$)"
            )
          }
        }
        return ""
      }
    }
  }

  enum NativeSwiftConversionCheck {
    case check32BitIntOverflow(typeWithMinAndMax: SwiftType)

    // Returns the check string
    func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
      switch self {
      case .check32BitIntOverflow(let minMaxSource):
        return "\(placeholder) >= \(minMaxSource).min && \(placeholder) <= \(minMaxSource).max"
      }
    }
  }
}
