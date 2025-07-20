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
    /// Translates a Swift function into the native JNI method signature.
    func translate(
      functionSignature: SwiftFunctionSignature,
      translatedFunctionSignature: TranslatedFunctionSignature
    ) throws -> NativeFunctionSignature {
      let parameters = try zip(translatedFunctionSignature.parameters, functionSignature.parameters).map { translatedParameter, swiftParameter in
        let parameterName = translatedParameter.parameter.name
        return try translate(swiftParameter: swiftParameter, parameterName: parameterName)
      }

      // Lower the self parameter.
      let nativeSelf: NativeParameter? = switch functionSignature.selfParameter {
      case .instance(let selfParameter):
        try translate(
          swiftParameter: selfParameter,
          parameterName: selfParameter.parameterName ?? "self"
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
      parameterName: String
    ) throws -> NativeParameter {
      switch swiftParameter.type {
      case .nominal(let nominalType):
        if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
          guard let javaType = JNISwift2JavaGenerator.translate(knownType: knownType), javaType.implementsJavaValue else {
            throw JavaTranslationError.unsupportedSwiftType(swiftParameter.type)
          }

          return NativeParameter(
            javaParameter: JavaParameter(name: parameterName, type: javaType),
            conversion: .initFromJNI(.placeholder, swiftType: swiftParameter.type)
          )
        }

      case .tuple([]):
        return NativeParameter(
          javaParameter: JavaParameter(name: parameterName, type: .void),
          conversion: .placeholder
        )

      case .metatype, .optional, .tuple, .function, .existential, .opaque:
        throw JavaTranslationError.unsupportedSwiftType(swiftParameter.type)
      }

      // Classes are passed as the pointer.
      return NativeParameter(
        javaParameter: JavaParameter(name: parameterName, type: .long),
        conversion: .pointee(.extractSwiftValue(.placeholder, swiftType: swiftParameter.type))
      )
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

      case .tuple([]):
        return NativeResult(
          javaType: .void,
          conversion: .placeholder
        )

      case .metatype, .optional, .tuple, .function, .existential, .opaque:
        throw JavaTranslationError.unsupportedSwiftType(swiftResult.type)
      }

      // TODO: Handle other classes, for example from JavaKit macros.
      // for now we assume all passed in classes are JExtract generated
      // so we pass the pointer.
      return NativeResult(
        javaType: .long,
        conversion: .getJNIValue(.allocateSwiftValue(name: "_result", swiftType: swiftResult.type))
      )
    }
  }

  struct NativeFunctionSignature {
    let selfParameter: NativeParameter?
    let parameters: [NativeParameter]
    let result: NativeResult
  }

  struct NativeParameter {
    let javaParameter: JavaParameter

    var jniType: JNIType {
      javaParameter.type.jniType
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

    /// `SwiftType(from: value, in: environment!)`
    indirect case initFromJNI(NativeSwiftConversionStep, swiftType: SwiftType)

    /// Extracts a swift type at a pointer given by a long.
    indirect case extractSwiftValue(NativeSwiftConversionStep, swiftType: SwiftType)

    /// Allocate memory for a Swift value and outputs the pointer
    indirect case allocateSwiftValue(name: String, swiftType: SwiftType)

    /// The thing to which the pointer typed, which is the `pointee` property
    /// of the `Unsafe(Mutable)Pointer` types in Swift.
    indirect case pointee(NativeSwiftConversionStep)


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
        printer.print(
          """
          let \(name)$ = UnsafeMutablePointer<\(swiftType)>.allocate(capacity: 1)
          \(name)$.initialize(to: \(placeholder))
          let \(name)Bits$ = Int64(Int(bitPattern: \(name)$))
          """
        )
        return "\(name)Bits$"

      case .pointee(let inner):
        let inner = inner.render(&printer, placeholder)
        return "\(inner).pointee"
      }
    }
  }
}
