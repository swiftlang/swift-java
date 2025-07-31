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

extension JNISwift2JavaGenerator {
  
  struct NativeJavaTranslation {
    let javaPackage: String
    let javaClassLookupTable: JavaClassLookupTable

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
        return try translate(
          swiftParameter: swiftParameter,
          parameterName: parameterName,
          methodName: methodName,
          parentName: parentName
        )
      }

      // Lower the self parameter.
      let nativeSelf: NativeParameter? = switch functionSignature.selfParameter {
      case .instance(let selfParameter):
        try translate(
          swiftParameter: selfParameter,
          parameterName: selfParameter.parameterName ?? "self",
          methodName: methodName,
          parentName: parentName
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

    func translate(
      swiftParameter: SwiftParameter,
      parameterName: String,
      methodName: String,
      parentName: String
    ) throws -> NativeParameter {
      switch swiftParameter.type {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(swiftParameter.type)
            }
            return try translateOptionalParameter(
              wrappedType: genericArgs[0],
              parameterName: parameterName
            )

          default:
            guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
              throw JavaTranslationError.unsupportedSwiftType(swiftParameter.type)
            }

            return NativeParameter(
              parameters: [
                JavaParameter(name: parameterName, type: javaType)
              ],
              conversion: .initFromJNI(.placeholder, swiftType: swiftParameter.type)
            )
          }
        }

        if nominalType.isJavaKitWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromJavaKitName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftParameter.type)
          }

          return NativeParameter(
            parameters: [
              JavaParameter(name: parameterName, type: javaType)
            ],
            conversion: .initializeJavaKitWrapper(wrapperName: nominalTypeName)
          )
        }

        // JExtract classes are passed as the pointer.
        return NativeParameter(
          parameters: [
            JavaParameter(name: parameterName, type: .long)
          ],
          conversion: .pointee(.extractSwiftValue(.placeholder, swiftType: swiftParameter.type))
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
            JavaParameter(name: parameterName, type: .class(package: javaPackage, name: "\(parentName).\(methodName).\(parameterName)"),)
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

      case .metatype, .tuple, .existential, .opaque:
        throw JavaTranslationError.unsupportedSwiftType(swiftParameter.type)
      }
    }

    func translateOptionalParameter(
      wrappedType swiftType: SwiftType,
      parameterName: String
    ) throws -> NativeParameter {
      let descriptorParameter = JavaParameter(name: "\(parameterName)_descriptor", type: .byte)
      let valueName = "\(parameterName)_value"

      switch swiftType {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          return NativeParameter(
            parameters: [
              descriptorParameter,
              JavaParameter(name: valueName, type: javaType)
            ],
            conversion: .optionalLowering(.initFromJNI(.placeholder, swiftType: swiftType))
          )
        }

        guard !nominalType.isJavaKitWrapper else {
          throw JavaTranslationError.unsupportedSwiftType(swiftType)
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
      wrappedType swiftType: SwiftType
    ) throws -> NativeResult {
      switch swiftType {
      case .nominal(let nominalType):
        let nominalTypeName = nominalType.nominalTypeDecl.name

        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
            throw JavaTranslationError.unsupportedSwiftType(swiftType)
          }

          // Check if we can fit the value and a discriminator byte in a primitive.
          // so the return JNI value will be (value || discriminator)
          if let nextIntergralTypeWithSpaceForByte = javaType.nextIntergralTypeWithSpaceForByte {
            return NativeResult(
              javaType: nextIntergralTypeWithSpaceForByte.java,
              conversion: .getJNIValue(
                .optionalRaisingWidenIntegerType(
                  .placeholder,
                  valueType: javaType,
                  combinedSwiftType: nextIntergralTypeWithSpaceForByte.swift,
                  valueSizeInBytes: nextIntergralTypeWithSpaceForByte.valueBytes
                )
              ),
              outParameters: []
            )
          } else {
            // Use indirect byte array to store discriminator
            let discriminatorName = "result_discriminator$"

            return NativeResult(
              javaType: javaType,
              conversion: .optionalRaisingIndirectReturn(
                .getJNIValue(.optionalChain(.placeholder)),
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
        // TODO: Should be the same as above, just with a long and different conversion?
        throw JavaTranslationError.unsupportedSwiftType(swiftType)

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
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
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

      case .function, .metatype, .optional, .tuple, .existential, .opaque:
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
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
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

      case .function, .metatype, .optional, .tuple, .existential, .opaque:
        throw JavaTranslationError.unsupportedSwiftType(type)
      }
    }

    func translate(
      swiftResult: SwiftResult
    ) throws -> NativeResult {
      switch swiftResult.type {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          switch knownType {
          case .optional:
            guard let genericArgs = nominalType.genericArguments, genericArgs.count == 1 else {
              throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
            }
            return try translateOptionalResult(wrappedType: swiftResult.type)

          default:
            guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
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
          conversion: .getJNIValue(.allocateSwiftValue(name: "result", swiftType: swiftResult.type)),
          outParameters: []
        )

      case .tuple([]):
        return NativeResult(
          javaType: .void,
          conversion: .placeholder,
          outParameters: []
        )

      case .optional(let wrapped):
        return try translateOptionalResult(wrappedType: wrapped)

      case .metatype, .tuple, .function, .existential, .opaque:
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

    /// `value.getJNIValue(in:)`
    indirect case getJNIValue(NativeSwiftConversionStep)

    /// `value.getJValue(in:)`
    indirect case getJValue(NativeSwiftConversionStep)

    /// `SwiftType(from: value, in: environment!)`
    indirect case initFromJNI(NativeSwiftConversionStep, swiftType: SwiftType)

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

    case initializeJavaKitWrapper(wrapperName: String)

    indirect case optionalLowering(NativeSwiftConversionStep)

    indirect case optionalChain(NativeSwiftConversionStep)

    indirect case optionalRaisingWidenIntegerType(NativeSwiftConversionStep, valueType: JavaType, combinedSwiftType: String, valueSizeInBytes: Int)

    indirect case optionalRaisingIndirectReturn(NativeSwiftConversionStep, discriminatorParameterName: String, placeholderValue: NativeSwiftConversionStep)

    indirect case method(NativeSwiftConversionStep, function: String, arguments: [(String?, NativeSwiftConversionStep)] = [])

    indirect case member(NativeSwiftConversionStep, member: String)

    /// Returns the conversion string applied to the placeholder.
    func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
      // NOTE: 'printer' is used if the conversion wants to cause side-effects.
      // E.g. storing a temporary values into a variable.
      switch self {
      case .placeholder:
        return placeholder

      case .constant(let value):
        return value

      case .getJNIValue(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).getJNIValue(in: environment!)"

      case .getJValue(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).getJValue(in: environment!)"

      case .initFromJNI(let inner, let swiftType):
        let inner = inner.render(&printer, placeholder)
        return "\(swiftType)(fromJNI: \(inner), in: environment!)"

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
          parameterTypes: parameters.flatMap { $0.parameters.map(\.type) }
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

        let upcall = "environment!.interface.\(nativeResult.javaType.jniType.callMethodAName)(environment, \(placeholder), methodID$, arguments$)"
        let result = nativeResult.conversion.render(&printer, upcall)

        if nativeResult.javaType.isVoid {
          printer.print(result)
        } else {
          printer.print("return \(result)")
        }

        printer.outdent()
        printer.print("}")

        return printer.finalize()

      case .initializeJavaKitWrapper(let wrapperName):
        return "\(wrapperName)(javaThis: \(placeholder), environment: environment!)"

      case .optionalLowering(let valueConversion):
        let value = valueConversion.render(&printer, "\(placeholder)_value")
        return "\(placeholder)_descriptor == 1 ? \(value) : nil"

      case .optionalChain(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner)?"

      case .optionalRaisingWidenIntegerType(let inner, let valueType, let combinedSwiftType, let valueSizeInBytes):
        let inner = inner.render(&printer, placeholder)
        let value = valueType == .boolean ? "$0 ? 1 : 0" : "$0"
        printer.print(
          """
          let value$: \(combinedSwiftType) = \(inner).map {
            \(combinedSwiftType)(\(value)) << \(valueSizeInBytes * 8) | \(combinedSwiftType)(1)
          } ?? 0
          """
        )
        return "value$"

      case .optionalRaisingIndirectReturn(let inner, let discriminatorParameterName, let placeholderValue):
        let inner = inner.render(&printer, placeholder)
        let placeholderValue = placeholderValue.render(&printer, placeholder)
        printer.print(
          """
          let result$ = \(inner)
          var flag$ = result$ != nil ? jbyte(1) : jbyte(2) 
          environment.interface.SetByteArrayRegion(environment, \(discriminatorParameterName), 0, 1, &flag$)
          """
        )
        return "result$ ?? \(placeholderValue)"

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
      }
    }
  }
}
