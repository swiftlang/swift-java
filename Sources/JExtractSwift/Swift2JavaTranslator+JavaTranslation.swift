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
    swiftSignature: SwiftFunctionSignature
  ) throws -> TranslatedFunctionSignature {
    let lowering = CdeclLowering(swiftStdlibTypes: self.swiftStdlibTypes)
    let loweredSignature = try lowering.lowerFunctionSignature(swiftSignature)

    let translation = JavaTranslation(swiftStdlibTypes: self.swiftStdlibTypes)
    let translated = try translation.translate(loweredFunctionSignature: loweredSignature)

    return translated
  }
}

/// Represent a parameter in Java code.
struct JavaParameter {
  /// The type.
  var type: JavaType

  /// The name.
  var name: String
}

/// Represent a Swift API parameter translated to Java.
struct TranslatedParameter {
  /// Java parameter(s) mapped to the Swift parameter.
  ///
  /// Array because one Swift parameter can be mapped to multiple parameters.
  var javaParameters: [JavaParameter]

  /// Describes how to convert the Java parameter to the lowered arguments for
  /// the foreign function.
  var conversion: JavaConversionStep
}

/// Represent a Swift API result translated to Java.
struct TranslatedResult {
  /// Java type that represents the Swift result type.
  var javaResultType: JavaType

  /// Required indirect return receivers for receiving the result.
  ///
  /// 'JavaParameter.name' is the suffix for the receiver variable names. For example
  ///
  ///   var _result_pointer = MemorySegment.allocate(...)
  ///   var _result_count = MemroySegment.allocate(...)
  ///   downCall(_result_pointer, _result_count)
  ///   return constructResult(_result_pointer, _result_count)
  ///
  /// This case, there're two out parameter, named '_pointer' and '_count'.
  var outParameters: [JavaParameter]

  /// Describes how to construct the Java result from the foreign function return
  /// value and/or the out parameters.
  var conversion: JavaConversionStep
}

/// Translated function signature representing a Swift API.
///
/// Since this holds the lowered signature, and the original `SwiftFunctionSignature`
/// in it, this contains all the API information (except the name) to generate the
/// cdecl thunk, Java binding, and the Java wrapper function.
struct TranslatedFunctionSignature {
  var loweredSignature: LoweredFunctionSignature

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

  /// Translate Swift API to user-facing Java API.
  ///
  /// Note that the result signature is for the high-level Java API, not the
  /// low-level FFM down-calling interface.
  func translate(
    loweredFunctionSignature: LoweredFunctionSignature
  ) throws -> TranslatedFunctionSignature {
    let swiftSignature = loweredFunctionSignature.original

    // 'self'
    let selfParameter: TranslatedParameter?
    if case .instance(let swiftSelf) = swiftSignature.selfParameter {
      selfParameter = try self.translate(
        swiftParam: swiftSelf,
        loweredParam: loweredFunctionSignature.selfParameter!,
        parameterName: swiftSelf.parameterName ?? "self"
      )
    } else {
      selfParameter = nil
    }

    // Regular parameters.
    let parameters: [TranslatedParameter] = try swiftSignature.parameters.enumerated()
      .map { (idx, swiftParam) in
        let loweredParam = loweredFunctionSignature.parameters[idx]
        let parameterName = swiftParam.parameterName ?? "_\(idx)"
        return try self.translate(
          swiftParam: swiftParam,
          loweredParam: loweredParam,
          parameterName: parameterName
        )
      }

    // Result.
    let result = try self.translate(
      swiftResult: swiftSignature.result,
      loweredResult: loweredFunctionSignature.result
    )

    return TranslatedFunctionSignature(
      loweredSignature: loweredFunctionSignature,
      selfParameter: selfParameter,
      parameters: parameters,
      result: result
    )
  }

  /// Translate
  func translate(
    swiftParam: SwiftParameter,
    loweredParam: LoweredParameter,
    parameterName: String
  ) throws -> TranslatedParameter {
    let swiftType = swiftParam.type

    // If there is a 1:1 mapping between this Swift type and a C type, that can
    // be expressed as a Java primitive type.
    if let cType = try? CType(cdeclType: swiftType) {
      let javaType = cType.javaType
      return TranslatedParameter(
        javaParameters: [
          JavaParameter(
            type: javaType,
            name: loweredParam.cdeclParameters[0].parameterName!
          )
        ],
        conversion: .pass
      )
    }

    switch swiftType {
    case .metatype:
      // Metatype are expressed as 'org.swift.swiftkit.SwiftAnyType'
      return TranslatedParameter(
        javaParameters: [
          JavaParameter(
            type: JavaType.class(package: "org.swift.swiftkit", name: "SwiftAnyType"),
            name: loweredParam.cdeclParameters[0].parameterName!)
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
                type: .javaLangString,
                name: loweredParam.cdeclParameters[0].parameterName!
              )
            ],
            conversion: .call(function: "SwiftKit.toCString", withArena: true)
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
            type: try translate(swiftType: swiftType),
            name: loweredParam.cdeclParameters[0].parameterName!
          )
        ],
        conversion: .swiftValueSelfSegment
      )

    case .tuple:
      // TODO: Implement.
      throw JavaTranslationError.unhandledType(swiftType)

    case .function(let fn) where fn.parameters.isEmpty && fn.resultType.isVoid:
      return TranslatedParameter(
        javaParameters: [
          JavaParameter(
            type: JavaType.class(package: "java.lang", name: "Runnable"),
            name: loweredParam.cdeclParameters[0].parameterName!)
        ],
        conversion: .call(function: "SwiftKit.toUpcallStub", withArena: true)
      )

    case .optional, .function:
      throw JavaTranslationError.unhandledType(swiftType)
    }
  }

  func translate(
    swiftResult: SwiftResult,
    loweredResult: LoweredResult
  ) throws -> TranslatedResult {
    let swiftType = swiftResult.type

    // If there is a 1:1 mapping between this Swift type and a C type, that can
    // be expressed as a Java primitive type.
    if let cType = try? CType(cdeclType: swiftType) {
      let javaType = cType.javaType
      return TranslatedResult(
        javaResultType: javaType,
        outParameters: [],
        conversion: .pass
      )
    }

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
          JavaParameter(type: javaType, name: "")
        ],
        conversion: .constructSwiftValue(javaType)
      )

    case .tuple:
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

  // Call 'new \(Type)(\(placeholder), swiftArena$)'.
  case constructSwiftValue(JavaType)

  // Construct the type using the placeholder as arguments.
  case construct(JavaType)

  // Casting the placeholder to the certain type.
  case cast(JavaType)
}

extension CType {
  /// Map lowered C type to Java type for FFM binding.
  var javaType: JavaType {
    switch self {
    case .void: return .void

    case .integral(.bool): return .boolean
    case .integral(.signed(bits: 8)): return .byte
    case .integral(.signed(bits: 16)): return .short
    case .integral(.signed(bits: 32)): return .int
    case .integral(.signed(bits: 64)): return .long
    case .integral(.unsigned(bits: 8)): return .byte
    case .integral(.unsigned(bits: 16)): return .short
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
    case .integral(.signed(bits: _)),  .integral(.unsigned(bits: _)):
      fatalError("unreachable")
    }
  }

  /// Map lowered C type to FFM ValueLayout.
  var foreignValueLayout: ForeignValueLayout {
    switch self {
    case .integral(.bool): return .SwiftBool
    case .integral(.signed(bits: 8)): return .SwiftInt8
    case .integral(.signed(bits: 16)): return .SwiftInt16
    case .integral(.signed(bits: 32)): return .SwiftInt32
    case .integral(.signed(bits: 64)): return .SwiftInt64

    case .integral(.unsigned(bits: 8)): return .SwiftInt8
    case .integral(.unsigned(bits: 16)): return .SwiftInt16
    case .integral(.unsigned(bits: 32)): return .SwiftInt32
    case .integral(.unsigned(bits: 64)): return .SwiftInt64

    case .floating(.double): return .SwiftDouble
    case .floating(.float): return .SwiftFloat

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
