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

import SwiftJNI
import SwiftJavaConfigurationShared

extension JNISwift2JavaGenerator {
  
  struct NativeJavaTranslation {
    let config: Configuration
    let javaPackage: String
    let javaClassLookupTable: JavaClassLookupTable
    var knownTypes: SwiftKnownTypes

    /// Translates a Swift function into the native JNI method signature.
    func translate(
      functionSignature: SwiftFunctionSignature,
      translatedFunctionSignature: TranslatedFunctionSignature,
      methodName: String,
      parentName: String
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
      let nativeSelf: NativeParameter? = switch functionSignature.selfParameter {
      case .instance(let selfParameter):
        try translateParameter(
          type: selfParameter.type,
          parameterName: selfParameter.parameterName ?? "self",
          methodName: methodName,
          parentName: parentName,
          genericParameters: functionSignature.genericParameters,
          genericRequirements: functionSignature.genericRequirements
        )
      case nil, .initializer(_), .staticMethod(_):
        nil
      }

      return try NativeFunctionSignature(
        selfParameter: nativeSelf,
        parameters: parameters,
        result: translate(swiftResult: functionSignature.result)
      )
    }

    func translateParameters(
      _ parameters: [SwiftParameter],
      translatedParameters: [TranslatedParameter],
      methodName: String,
      parentName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement]
    ) throws -> [NativeParameter] {
      try zip(translatedParameters, parameters).map { translatedParameter, swiftParameter in
        let parameterName = translatedParameter.parameter.name
        return try translateParameter(
          type: swiftParameter.type,
          parameterName: parameterName,
          methodName: methodName,
          parentName: parentName,
          genericParameters: genericParameters,
          genericRequirements: genericRequirements
        )
      }
    }

    func translateParameter(
      type: SwiftType,
      parameterName: String,
      methodName: String,
      parentName: String,
      genericParameters: [SwiftGenericParameterDeclaration],
      genericRequirements: [SwiftGenericRequirement]
    ) throws -> NativeParameter {
      switch type {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(type)
            }
            return try translateOptionalParameter(
              wrappedType: genericArgs[0],
              parameterName: parameterName
            )

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
                  javaType.implementsJavaValue else {
              throw JavaTranslationError.unsupportedSwiftType(type)
            }

            return NativeParameter(
              parameters: [
                JavaParameter(name: parameterName, type: javaType)
              ],
              conversion: .initFromJNI(.placeholder, swiftType: type)
            )

          }
        }

        if nominalType.isJavaKitWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromJavaKitName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(type)
          }

          return NativeParameter(
            parameters: [
              JavaParameter(name: parameterName, type: javaType)
            ],
            conversion: .initializeJavaKitWrapper(
              .unwrapOptional(
                .placeholder,
                name: parameterName,
                fatalErrorMessage: "\(parameterName) was null in call to \\(#function), but Swift requires non-optional!"
              ),
              wrapperName: nominalTypeName
            )
          )
        }

        // JExtract classes are passed as the pointer.
        return NativeParameter(
          parameters: [
            JavaParameter(name: parameterName, type: .long)
          ],
          conversion: .pointee(.extractSwiftValue(.placeholder, swiftType: type))
        )

      case .tuple([]):
        return NativeParameter(
          parameters: [
            JavaParameter(name: parameterName, type: .void)
          ],
          conversion: .placeholder
        )

      case .function(let fn):
        var parameters = [NativeParameter]()
        for (i, parameter) in fn.parameters.enumerated() {
          let parameterName = parameter.parameterName ?? "_\(i)"
          let closureParameter = try translateClosureParameter(
            parameter.type,
            parameterName: parameterName
          )
          parameters.append(closureParameter)
        }

        let result = try translateClosureResult(fn.resultType)

        return NativeParameter(
          parameters: [
            JavaParameter(name: parameterName, type: .class(package: javaPackage, name: "\(parentName).\(methodName).\(parameterName)"))
          ],
          conversion: .closureLowering(
            parameters: parameters,
            result: result
          )
        )

      case .optional(let wrapped):
        return try translateOptionalParameter(
          wrappedType: wrapped,
          parameterName: parameterName
        )

      case .opaque(let proto), .existential(let proto):
        return try translateProtocolParameter(
          protocolType: proto,
          parameterName: parameterName
        )

      case .genericParameter:
        if let concreteTy = type.typeIn(genericParameters: genericParameters, genericRequirements: genericRequirements) {
          return try translateProtocolParameter(
            protocolType: concreteTy,
            parameterName: parameterName
          )
        }

        throw JavaTranslationError.unsupportedSwiftType(type)

      case .metatype, .tuple, .composite:
        throw JavaTranslationError.unsupportedSwiftType(type)
      }
    }

    func translateProtocolParameter(
      protocolType: SwiftType,
      parameterName: String
    ) throws -> NativeParameter {
      switch protocolType {
      case .nominal(let nominalType):
        let protocolName = nominalType.nominalTypeDecl.qualifiedName
        return try translateProtocolParameter(protocolNames: [protocolName], parameterName: parameterName)

      case .composite(let types):
        let protocolNames = try types.map {
          guard let nominalTypeName = $0.asNominalType?.nominalTypeDecl.qualifiedName else {
            throw JavaTranslationError.unsupportedSwiftType($0)
          }
          return nominalTypeName
        }

        return try translateProtocolParameter(protocolNames: protocolNames, parameterName: parameterName)

      default:
        throw JavaTranslationError.unsupportedSwiftType(protocolType)
      }
    }

    private func translateProtocolParameter(
      protocolNames: [String],
      parameterName: String
    ) throws -> NativeParameter {
      return NativeParameter(
        parameters: [
          JavaParameter(name: parameterName, type: .long),
          JavaParameter(name: "\(parameterName)_typeMetadataAddress", type: .long)
        ],
        conversion: .extractSwiftProtocolValue(
          .placeholder,
          typeMetadataVariableName: .combinedName(component: "typeMetadataAddress"),
          protocolNames: protocolNames
        )
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
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
                javaType.implementsJavaValue else {
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          return NativeParameter(
            parameters: [
              JavaParameter(name: discriminatorName, type: .byte),
              JavaParameter(name: valueName, type: javaType)
            ],
            conversion: .optionalLowering(
              .initFromJNI(.placeholder, swiftType: swiftType),
              discriminatorName: discriminatorName,
              valueName: valueName
            )
          )
        }

        if nominalType.isJavaKitWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromJavaKitName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftType)
          }

          return NativeParameter(
            parameters: [
              JavaParameter(name: parameterName, type: javaType)
            ],
            conversion: .optionalMap(.initializeJavaKitWrapper(.placeholder, wrapperName: nominalTypeName))
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
          )
        )

      default:
        throw JavaTranslationError.unsupportedSwiftType(swiftType)
      }
    }

    func translateOptionalResult(
      wrappedType swiftType: SwiftType,
      resultName: String = "result"
    ) throws -> NativeResult {
      let discriminatorName = "\(resultName)_discriminator$"

      switch swiftType {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
                javaType.implementsJavaValue else {
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

        guard !nominalType.isJavaKitWrapper else {
          // TODO: Should be the same as above
          throw JavaTranslationError.unsupportedSwiftType(swiftType)
        }

        // Assume JExtract imported class
        return NativeResult(
          javaType: .long,
          conversion: .optionalRaisingIndirectReturn(
            .getJNIValue(.allocateSwiftValue(name: "_result", swiftType: swiftType)),
            returnType: .long,
            discriminatorParameterName: discriminatorName,
            placeholderValue: .constant("0")
          ),
          outParameters: [
            JavaParameter(name: discriminatorName, type: .array(.byte))
          ]
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
          guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config),
              javaType.implementsJavaValue else {
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

      case .function, .metatype, .optional, .tuple, .existential, .opaque, .genericParameter, .composite:
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
              javaType.implementsJavaValue else {
            throw JavaTranslationError.unsupportedSwiftType(type)
          }

          // Only support primitives for now.
          return NativeParameter(
            parameters: [
              JavaParameter(name: parameterName, type: javaType)
            ],
            conversion: .getJValue(.placeholder)
          )
        }

        // Custom types are not supported yet.
        throw JavaTranslationError.unsupportedSwiftType(type)

      case .function, .metatype, .optional, .tuple, .existential, .opaque, .genericParameter, .composite:
        throw JavaTranslationError.unsupportedSwiftType(type)
      }
    }

    func translate(
      swiftResult: SwiftResult,
      resultName: String = "result"
    ) throws -> NativeResult {
      switch swiftResult.type {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
            }
            return try translateOptionalResult(wrappedType: genericArgs[0], resultName: resultName)

          default:
            guard let javaType = JNIJavaTypeTranslator.translate(knownType: knownType, config: self.config), javaType.implementsJavaValue else {
              throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
            }

            return NativeResult(
              javaType: javaType,
              conversion: .getJNIValue(.placeholder),
              outParameters: []
            )
          }
        }

        if nominalType.isJavaKitWrapper {
          throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
        }

        return NativeResult(
          javaType: .long,
          conversion: .getJNIValue(.allocateSwiftValue(name: resultName, swiftType: swiftResult.type)),
          outParameters: []
        )

      case .tuple([]):
        return NativeResult(
          javaType: .void,
          conversion: .placeholder,
          outParameters: []
        )

      case .optional(let wrapped):
        return try translateOptionalResult(wrappedType: wrapped, resultName: resultName)

      case .metatype, .tuple, .function, .existential, .opaque, .genericParameter, .composite:
        throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
      }
    }
  }

  struct NativeFunctionSignature {
    let selfParameter: NativeParameter?
    let parameters: [NativeParameter]
    let result: NativeResult
  }

  struct NativeParameter {
    /// One Swift parameter can be lowered to multiple parameters.
    /// E.g. 'Optional<Int>' as (descriptor, value) pair.
    var parameters: [JavaParameter]

    /// Represents how to convert the JNI parameter to a Swift parameter
    let conversion: NativeSwiftConversionStep
  }

  struct NativeResult {
    let javaType: JavaType
    let conversion: NativeSwiftConversionStep

    /// Out parameters for populating the indirect return values.
    var outParameters: [JavaParameter]
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

    /// `value.getJValue(in:)`
    indirect case getJValue(NativeSwiftConversionStep)

    /// `SwiftType(from: value, in: environment!)`
    indirect case initFromJNI(NativeSwiftConversionStep, swiftType: SwiftType)

    indirect case extractSwiftProtocolValue(
      NativeSwiftConversionStep,
      typeMetadataVariableName: NativeSwiftConversionStep,
      protocolNames: [String]
    )

    /// Extracts a swift type at a pointer given by a long.
    indirect case extractSwiftValue(
      NativeSwiftConversionStep,
      swiftType: SwiftType,
      allowNil: Bool = false
    )

    /// Allocate memory for a Swift value and outputs the pointer
    case allocateSwiftValue(name: String, swiftType: SwiftType)

    /// The thing to which the pointer typed, which is the `pointee` property
    /// of the `Unsafe(Mutable)Pointer` types in Swift.
    indirect case pointee(NativeSwiftConversionStep)

    indirect case closureLowering(parameters: [NativeParameter], result: NativeResult)

    indirect case initializeJavaKitWrapper(NativeSwiftConversionStep, wrapperName: String)

    indirect case optionalLowering(NativeSwiftConversionStep, discriminatorName: String, valueName: String)

    indirect case optionalChain(NativeSwiftConversionStep)

    indirect case optionalRaisingWidenIntegerType(NativeSwiftConversionStep, resultName: String, valueType: JavaType, combinedSwiftType: SwiftKnownTypeDeclKind, valueSizeInBytes: Int)

    indirect case optionalRaisingIndirectReturn(NativeSwiftConversionStep, returnType: JavaType, discriminatorParameterName: String, placeholderValue: NativeSwiftConversionStep)

    indirect case method(NativeSwiftConversionStep, function: String, arguments: [(String?, NativeSwiftConversionStep)] = [])

    indirect case member(NativeSwiftConversionStep, member: String)

    indirect case optionalMap(NativeSwiftConversionStep)

    indirect case unwrapOptional(NativeSwiftConversionStep, name: String, fatalErrorMessage: String)

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
        return "\(inner).getJNIValue(in: environment!)"

      case .getJValue(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).getJValue(in: environment!)"

      case .initFromJNI(let inner, let swiftType):
        let inner = inner.render(&printer, placeholder)
        return "\(swiftType)(fromJNI: \(inner), in: environment!)"

      case .extractSwiftProtocolValue(let inner, let typeMetadataVariableName, let protocolNames):
        let inner = inner.render(&printer, placeholder)
        let typeMetadataVariableName = typeMetadataVariableName.render(&printer, placeholder)
        let existentialName = "\(inner)Existential$"

        let compositeProtocolName = "(\(protocolNames.joined(separator: " & ")))"

        // TODO: Remove the _openExistential when we decide to only support language mode v6+
        printer.print(
          """
          guard let \(inner)TypeMetadataPointer$ = UnsafeRawPointer(bitPattern: Int(Int64(fromJNI: \(typeMetadataVariableName), in: environment!))) else {
            fatalError("\(typeMetadataVariableName) memory address was null")
          }
          let \(inner)DynamicType$: Any.Type = unsafeBitCast(\(inner)TypeMetadataPointer$, to: Any.Type.self)
          guard let \(inner)RawPointer$ = UnsafeMutableRawPointer(bitPattern: Int(Int64(fromJNI: \(inner), in: environment!))) else {
            fatalError("\(inner) memory address was null")
          }
          #if hasFeature(ImplicitOpenExistentials)
          let \(existentialName) = \(inner)RawPointer$.load(as: \(inner)DynamicType$) as! any \(compositeProtocolName)
          #else
          func \(inner)DoLoad<Ty>(_ ty: Ty.Type) -> any \(compositeProtocolName) {
            \(inner)RawPointer$.load(as: ty) as! any \(compositeProtocolName)
          }
          let \(existentialName) = _openExistential(\(inner)DynamicType$, do: \(inner)DoLoad)
          #endif
          """
        )
        return existentialName

      case .extractSwiftValue(let inner, let swiftType, let allowNil):
        let inner = inner.render(&printer, placeholder)
        let pointerName = "\(inner)$"
        if !allowNil {
          printer.print(#"assert(\#(inner) != 0, "\#(inner) memory address was null")"#)
        }
        printer.print(
          """
          let \(inner)Bits$ = Int(Int64(fromJNI: \(inner), in: environment!))
          let \(pointerName) = UnsafeMutablePointer<\(swiftType)>(bitPattern: \(inner)Bits$)
          """
        )
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

      case .allocateSwiftValue(let name, let swiftType):
        let pointerName = "\(name)$"
        let bitsName = "\(name)Bits$"
        printer.print(
          """
          let \(pointerName) = UnsafeMutablePointer<\(swiftType)>.allocate(capacity: 1)
          \(pointerName).initialize(to: \(placeholder))
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
            let class$ = environment!.interface.GetObjectClass(environment, \(placeholder))
            let methodID$ = environment!.interface.GetMethodID(environment, class$, "apply", "\(methodSignature.mangledName)")!
            let arguments$: [jvalue] = [\(arguments.joined(separator: ", "))]
            """
        )

        let upcall = "environment!.interface.\(nativeResult.javaType.jniCallMethodAName)(environment, \(placeholder), methodID$, arguments$)"
        let result = nativeResult.conversion.render(&printer, upcall)

        if nativeResult.javaType.isVoid {
          printer.print(result)
        } else {
          printer.print("return \(result)")
        }

        printer.outdent()
        printer.print("}")

        return printer.finalize()

      case .initializeJavaKitWrapper(let inner, let wrapperName):
        let inner = inner.render(&printer, placeholder)
        return "\(wrapperName)(javaThis: \(inner), environment: environment!)"

      case .optionalLowering(let valueConversion, let discriminatorName, let valueName):
        let value = valueConversion.render(&printer, valueName)
        return "\(discriminatorName) == 1 ? \(value) : nil"

      case .optionalChain(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner)?"

      case .optionalRaisingWidenIntegerType(let inner, let resultName, let valueType, let combinedSwiftType, let valueSizeInBytes):
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

      case .optionalRaisingIndirectReturn(let inner, let returnType, let discriminatorParameterName, let placeholderValue):
        printer.print("let result$: \(returnType.jniTypeName)")
        printer.printBraceBlock("if let innerResult$ = \(placeholder)") { printer in
          let inner = inner.render(&printer, "innerResult$")
          printer.print(
            """
            result$ = \(inner) 
            var flag$ = Int8(1)
            environment.interface.SetByteArrayRegion(environment, \(discriminatorParameterName), 0, 1, &flag$)
            """
          )
        }
        printer.printBraceBlock("else") { printer in
          let placeholderValue = placeholderValue.render(&printer, placeholder)
          printer.print(
            """
            result$ = \(placeholderValue)
            var flag$ = Int8(0)
            environment.interface.SetByteArrayRegion(environment, \(discriminatorParameterName), 0, 1, &flag$)
            """
          )
        }

        return "result$"

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
      }
    }
  }
}
