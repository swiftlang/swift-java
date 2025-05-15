//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaTypes

extension Swift2JavaTranslator {
  func translate(
    swiftSignature: SwiftFunctionSignature,
    as apiKind: SwiftAPIKind
  ) throws -> TranslatedFunctionSignature {
    let lowering = CdeclLowering(swiftStdlibTypes: self.swiftStdlibTypes)
    let loweredSignature = try lowering.lowerFunctionSignature(swiftSignature, apiKind: apiKind)

    let translation = JavaTranslation(swiftStdlibTypes: self.swiftStdlibTypes)
    let translated = try translation.translate(loweredFunctionSignature: loweredSignature)

    return translated
  }
}

/// Represent a parameter in Java code.
struct JavaParameter {
  /// The type.
  var javaType: JavaType

  /// The name.
  var parameterName: String
}

enum JavaModifier {
  // Access modifiers
  case `public`
  case `private`
  case `protected`

  // Non-access modifiers.
  case `final`
  case `static`
  case `abstract`
  case `transient`
  case `synchronized`
  case `volatile`
}

struct JavaMethodSignature {
  var modifiers: [JavaModifier]
  var returnType: JavaType
  var parameters: [JavaParameter]
}

struct TranslatedParameter {
  var javaParameters: [JavaParameter]
  var conversion: JavaConversionStep
}

struct TranslatedResult {
  var javaResultType: JavaType
  var outParameters: [JavaParameter]
  var conversion: JavaConversionStep
}

struct TranslatedFunctionSignature {
  var loweredSignature: LoweredFunctionSignature

  ///
  var selfParameter: TranslatedParameter?
  var parameters: [TranslatedParameter]
  var result: TranslatedResult
}

extension TranslatedFunctionSignature {
  /// Whether or not if the down-calling requires temporary "Arena" which is
  /// only used during the down-calling.
  var requiresTemporaryArena: Bool {
    if self.parameters.contains(where: { $0.conversion.requiresTemporaryArena }) {
      return true
    }
    if self.selfParameter?.conversion.requiresTemporaryArena ?? false {
      return true
    }
    if self.result.conversion.requiresTemporaryArena {
      return true
    }
    return false
  }

  /// Whether if the down-calling requires "SwiftArena" or not, which should be
  /// passed-in by the API caller. This is needed if the API returns a `SwiftValue`
  var requiresSwiftArena: Bool {
    return self.result.conversion.requiresSwiftArena
  }
}

struct JavaTranslation {
  var swiftStdlibTypes: SwiftStandardLibraryTypes

  func translate(
    loweredFunctionSignature: LoweredFunctionSignature
  ) throws -> TranslatedFunctionSignature {

    // 'self'
    let selfParameter: TranslatedParameter?
    if let loweredSelf = loweredFunctionSignature.selfParameter {
      guard case .instance(let swiftSelf) = loweredFunctionSignature.original.selfParameter! else {
        fatalError("unreachable")
      }
      selfParameter = try self.translate(
        loweredParam: loweredSelf,
        swiftParam: swiftSelf,
        parameterName: swiftSelf.parameterName ?? "self"
      )
    } else {
      selfParameter = nil
    }

    // Regular parameters.
    let parameters: [TranslatedParameter] = try loweredFunctionSignature.parameters.enumerated()
      .map { (idx, loweredParam) in
        let swiftParam = loweredFunctionSignature.original.parameters[idx]
        let parameterName = swiftParam.parameterName ?? "_\(idx)"
        return try self.translate(
          loweredParam: loweredParam,
          swiftParam: swiftParam,
          parameterName: parameterName
        )
      }

    // Result.
    var result = try self.translate(
      loweredResult: loweredFunctionSignature.result,
      swiftResult: loweredFunctionSignature.original.result
    )

    return TranslatedFunctionSignature(
      loweredSignature: loweredFunctionSignature,
      selfParameter: selfParameter,
      parameters: parameters,
      result: result
    )
  }

  func translate(
    loweredParam: LoweredParameter,
    swiftParam: SwiftParameter,
    parameterName: String
  ) throws -> TranslatedParameter {
    // If there is a 1:1 mapping between this Swift type and a C type.z
    if let cType = try? CType(cdeclType: swiftParam.type) {
      if let javaType = JavaType(cType: cType) {
        return TranslatedParameter(
          javaParameters: [
            JavaParameter(
              javaType: javaType,
              parameterName: loweredParam.cdeclParameters[0].parameterName!
            )
          ],
          conversion: .pass
        )
      }
    }
    let swiftType = swiftParam.type

    switch swiftType {
    case .metatype(let swiftType):
      // Metatype are expressed as 'org.swift.swiftkit.SwiftAnyType'
      return TranslatedParameter(
        javaParameters: [
          JavaParameter(
            javaType: JavaType.class(package: "org.swift.swiftkit", name: "SwiftAnyType"),
            parameterName: loweredParam.cdeclParameters[0].parameterName!)
        ],
        conversion: .swiftValueSelfSegment
      )

    case .nominal(let swiftNominalType):
      if let knownType = swiftNominalType.nominalTypeDecl.knownStandardLibraryType {
        if swiftParam.convention == .inout {
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

        case .string:
          return TranslatedParameter(
            javaParameters: [
              JavaParameter(
                javaType: .javaLangString,
                parameterName: loweredParam.cdeclParameters[0].parameterName!
              )
            ],
            conversion: .call(function: "SwiftKit.toCString", withArena: true)
          )

        case .int:
          return TranslatedParameter(
            javaParameters: [
              JavaParameter(
                javaType: .long,
                parameterName: loweredParam.cdeclParameters[0].parameterName!
              )
            ],
            conversion: .call(function: "SwiftKit.toSwiftInt", withArena: false)
          )

        default:
          throw JavaTranslationError.unhandledType(swiftType)
        }
      }

      // Generic types are not supported yet.
      guard swiftNominalType.genericArguments == nil else {
        throw JavaTranslationError.unhandledType(swiftType)
      }

      return TranslatedParameter(
        javaParameters: [
          JavaParameter(
            javaType: try translate(swiftType: swiftType),
            parameterName: loweredParam.cdeclParameters[0].parameterName!
          )
        ],
        conversion: .swiftValueSelfSegment
      )

    case .tuple(let elements):
      // TODO: Implement.
      throw JavaTranslationError.unhandledType(swiftType)

    case .function(let fn) where fn.parameters.isEmpty && fn.resultType.isVoid:
      return TranslatedParameter(
        javaParameters: [
          JavaParameter(
            javaType: JavaType.class(package: "java.lang", name: "Runnable"),
            parameterName: loweredParam.cdeclParameters[0].parameterName!)
        ],
        conversion: .call(function: "SwiftKit.toUpcallStub", withArena: true)
      )

    case .optional, .function:
      throw JavaTranslationError.unhandledType(swiftType)
    }
  }

  func translate(
    loweredResult: LoweredResult,
    swiftResult: SwiftResult
  ) throws -> TranslatedResult {
    // If there is a 1:1 mapping between this Swift type and a C type.z
    if let cType = try? CType(cdeclType: swiftResult.type) {
      if let javaType = JavaType(cType: cType) {
        return TranslatedResult(
          javaResultType: javaType,
          outParameters: [],
          conversion: .cast(javaType)
        )
      }
    }

    let swiftType = swiftResult.type
    switch swiftType {
    case .metatype(_):
      // Metatype are expressed as 'org.swift.swiftkit.SwiftAnyType'
      let javaType = JavaType.class(package: "org.swift.swiftkit", name: "SwiftAnyType")
      return TranslatedResult(
        javaResultType: javaType,
        outParameters: [],
        conversion: .construct(javaType)
      )

    case .nominal(let swiftNominalType):
      if let knownType = swiftNominalType.nominalTypeDecl.knownStandardLibraryType {
        switch knownType {
        case .unsafePointer, .unsafeMutablePointer:
          // FIXME: Implement
          throw JavaTranslationError.unhandledType(swiftType)
        case .unsafeBufferPointer, .unsafeMutableBufferPointer:
          // FIXME: Implement
          throw JavaTranslationError.unhandledType(swiftType)
        case .string:
          // FIXME: Implement
          throw JavaTranslationError.unhandledType(swiftType)
        case .int:
          return TranslatedResult(
            javaResultType: .long,
            outParameters: [],
            conversion: .cast(.long)
          )
        default:
          throw JavaTranslationError.unhandledType(swiftType)
        }
      }

      // Generic types are not supported yet.
      guard swiftNominalType.genericArguments == nil else {
        throw JavaTranslationError.unhandledType(swiftType)
      }

      let javaType: JavaType = .class(package: nil, name: swiftNominalType.nominalTypeDecl.name)
      return TranslatedResult(
        javaResultType: javaType,
        outParameters: [
          JavaParameter(javaType: javaType, parameterName: "_result")
        ],
        conversion: .constructSwiftValue(javaType)
      )

    case .tuple(let elements):
      // TODO: Implement.
      throw JavaTranslationError.unhandledType(swiftType)

    case .optional, .function:
      throw JavaTranslationError.unhandledType(swiftType)
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
  // Pass through.
  case pass

  // 'value.$memorySegment()'
  case swiftValueSelfSegment

  // call specified function using the placeholder as arguments.
  // If `withArena` is true, `arena$` argument is added.
  case call(function: String, withArena: Bool)

  // Call '\(Type)(\(placeholder), arena$)'.
  case constructSwiftValue(JavaType)

  // Construct the type using the placeholder as arguments.
  case construct(JavaType)

  // Casting the placeholder to the certain type.
  case cast(JavaType)
}


extension JavaType {
  init?(cType: CType) {
    switch cType {
    case .void: self = .void

    case .integral(.bool): self = .boolean
    case .integral(.signed(bits: 8)): self = .byte
    case .integral(.signed(bits: 16)): self = .short
    case .integral(.signed(bits: 32)): self = .int
    case .integral(.signed(bits: 64)): self = .long
    case .integral(.unsigned(bits: 8)): self = .byte
    case .integral(.unsigned(bits: 16)): self = .short
    case .integral(.unsigned(bits: 32)): self = .int
    case .integral(.unsigned(bits: 64)): self = .long

    case .floating(.float): self = .float
    case .floating(.double): self = .double

    // FIXME: 32 bit consideration.
    // The 'FunctionDescriptor' uses 'SWIFT_INT' which relies on the running
    // machine arch. That means users can't pass Java 'long' values to the
    // function without casting. But how do we generate code that runs both
    // 32 and 64 bit machine?
    case .integral(.ptrdiff_t): self = .long
    case .integral(.size_t): self = .long

    default: return nil
    }
  }
}

extension CType {
  var foreignValueLayout: ForeignValueLayout {
    switch self {
    case .integral(.bool):
      return .SwiftBool
    case .integral(.signed(bits: 8)):
      return .SwiftInt8
    case .integral(.signed(bits: 16)):
      return .SwiftInt16
    case .integral(.signed(bits: 32)):
      return .SwiftInt32
    case .integral(.signed(bits: 64)):
      return .SwiftInt64

    case .integral(.unsigned(bits: 8)):
      return .SwiftInt8
    case .integral(.unsigned(bits: 16)):
      return .SwiftInt16
    case .integral(.unsigned(bits: 32)):
      return .SwiftInt32
    case .integral(.unsigned(bits: 64)):
      return .SwiftInt64

    case .floating(.double):
      return .SwiftDouble
    case .floating(.float):
      return .SwiftFloat

    case .integral(.ptrdiff_t), .integral(.size_t):
      return .SwiftInt

    case .pointer(_), .function(resultType: _, parameters: _, variadic: _):
      return .SwiftPointer
    case .qualified(const: _, volatile: _, type: let inner):
      return inner.foreignValueLayout
    case .tag(_):
      fatalError("unsupported")
    case .void, .integral(.signed(bits: _)),  .integral(.unsigned(bits: _)):
      fatalError("unreachable")
    }
  }
}

enum JavaTranslationError: Error {
  case inoutNotSupported(SwiftType)
  case unhandledType(SwiftType)
}
