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
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
            throw JavaTranslationError.unsupportedSwiftType(swiftParameter.type)
          }

          return NativeParameter(
            name: parameterName,
            javaType: javaType,
            conversion: .initFromJNI(.placeholder, swiftType: swiftParameter.type)
          )
        }

        if nominalType.isJavaKitWrapper {
          guard let javaType = nominalTypeName.parseJavaClassFromJavaKitName(in: self.javaClassLookupTable) else {
            throw JavaTranslationError.wrappedJavaClassTranslationNotProvided(swiftParameter.type)
          }

          return NativeParameter(
            name: parameterName,
            javaType: javaType,
            conversion: .initializeJavaKitWrapper(wrapperName: nominalTypeName)
          )
        }

        // JExtract classes are passed as the pointer.
        return NativeParameter(
          name: parameterName,
          javaType: .long,
          conversion: .pointee(.extractSwiftValue(.placeholder, swiftType: swiftParameter.type))
        )

      case .tuple([]):
        return NativeParameter(
          name: parameterName,
          javaType: .void,
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
          name: parameterName,
          javaType: .class(package: javaPackage, name: "\(parentName).\(methodName).\(parameterName)"),
          conversion: .closureLowering(
            parameters: parameters,
            result: result
          )
        )

      case .metatype, .optional, .tuple, .existential, .opaque:
        throw JavaTranslationError.unsupportedSwiftType(swiftParameter.type)
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
            conversion: .initFromJNI(.placeholder, swiftType: type)
          )
        }

        // Custom types are not supported yet.
        throw JavaTranslationError.unsupportedSwiftType(type)

      case .tuple([]):
        return NativeResult(
          javaType: .void,
          conversion: .placeholder
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
            name: parameterName,
            javaType: javaType,
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
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
            throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
          }

          return NativeResult(
            javaType: javaType,
            conversion: .getJNIValue(.placeholder)
          )
        }

        if nominalType.isJavaKitWrapper {
          throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
        }

        return NativeResult(
          javaType: .long,
          conversion: .getJNIValue(.allocateSwiftValue(name: "result", swiftType: swiftResult.type))
        )

      case .tuple([]):
        return NativeResult(
          javaType: .void,
          conversion: .placeholder
        )

      case .metatype, .optional, .tuple, .function, .existential, .opaque:
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
    let name: String
    let javaType: JavaType

    var jniType: JNIType {
      javaType.jniType
    }

    /// Represents how to convert the JNI parameter to a Swift parameter
    let conversion: NativeSwiftConversionStep
  }

  struct NativeResult {
    let javaType: JavaType
    let conversion: NativeSwiftConversionStep
  }

  /// Describes how to convert values between Java types and Swift through JNI
  enum NativeSwiftConversionStep {
    /// The value being converted
    case placeholder

    /// `value.getJNIValue(in:)`
    indirect case getJNIValue(NativeSwiftConversionStep)

    /// `value.getJValue(in:)`
    indirect case getJValue(NativeSwiftConversionStep)

    /// `SwiftType(from: value, in: environment!)`
    indirect case initFromJNI(NativeSwiftConversionStep, swiftType: SwiftType)

    /// Extracts a swift type at a pointer given by a long.
    indirect case extractSwiftValue(NativeSwiftConversionStep, swiftType: SwiftType)

    /// Allocate memory for a Swift value and outputs the pointer
    case allocateSwiftValue(name: String, swiftType: SwiftType)

    /// The thing to which the pointer typed, which is the `pointee` property
    /// of the `Unsafe(Mutable)Pointer` types in Swift.
    indirect case pointee(NativeSwiftConversionStep)

    indirect case closureLowering(parameters: [NativeParameter], result: NativeResult)

    case initializeJavaKitWrapper(wrapperName: String)

    /// Returns the conversion string applied to the placeholder.
    func render(_ printer: inout CodePrinter, _ placeholder: String) -> String {
      // NOTE: 'printer' is used if the conversion wants to cause side-effects.
      // E.g. storing a temporary values into a variable.
      switch self {
      case .placeholder:
        return placeholder

      case .getJNIValue(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).getJNIValue(in: environment!)"

      case .getJValue(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).getJValue(in: environment!)"

      case .initFromJNI(let inner, let swiftType):
        let inner = inner.render(&printer, placeholder)
        return "\(swiftType)(fromJNI: \(inner), in: environment!)"

      case .extractSwiftValue(let inner, let swiftType):
        let inner = inner.render(&printer, placeholder)
        printer.print(
          """
          assert(\(inner) != 0, "\(inner) memory address was null")
          let \(inner)Bits$ = Int(Int64(fromJNI: \(inner), in: environment!))
          guard let \(inner)$ = UnsafeMutablePointer<\(swiftType)>(bitPattern: \(inner)Bits$) else {
            fatalError("\(inner) memory address was null in call to \\(#function)!")
          }
          """
        )
        return "\(inner)$"

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
          parameterTypes: parameters.map(\.javaType)
        )

        let closureParameters = !parameters.isEmpty ? "\(parameters.map(\.name).joined(separator: ", ")) in" : ""
        printer.print("{ \(closureParameters)")
        printer.indent()

        let arguments = parameters.map {
          $0.conversion.render(&printer, $0.name)
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
      }
    }
  }
}
