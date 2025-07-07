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

extension FFMSwift2JavaGenerator {
  func translatedDecl(
    for decl: ImportedFunc
  ) -> TranslatedFunctionDecl? {
    if let cached = translatedDecls[decl] {
      return cached
    }

    let translated: TranslatedFunctionDecl?
    do {
      let translation = JavaTranslation(symbolTable: self.symbolTable)
      translated = try translation.translate(decl)
    } catch {
      self.log.info("Failed to translate: '\(decl.swiftDecl.qualifiedNameForDebug)'; \(error)")
      translated = nil
    }

    translatedDecls[decl] = translated
    return translated
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

    /// Cdecl lowerd signature.
    let loweredSignature: LoweredFunctionSignature
  }

  /// Function signature for a Java API.
  struct TranslatedFunctionSignature {
    var selfParameter: TranslatedParameter?
    var parameters: [TranslatedParameter]
    var result: TranslatedResult
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

    /// Whether or not this functional interface with C ABI compatible.
    var isCompatibleWithC: Bool {
      result.conversion.isPlaceholder && parameters.allSatisfy(\.conversion.isPlaceholder)
    }
  }

  struct JavaTranslation {
    var symbolTable: SwiftSymbolTable

    func translate(
      _ decl: ImportedFunc
    ) throws -> TranslatedFunctionDecl {
      let lowering = CdeclLowering(symbolTable: symbolTable)
      let loweredSignature = try lowering.lowerFunctionSignature(decl.functionSignature)

      // Name.
      let javaName = switch decl.apiKind {
      case .getter: "get\(decl.name.toCamelCase)"
      case .setter: "set\(decl.name.toCamelCase)"
      case .function, .initializer: decl.name
      }

      // Signature.
      let translatedSignature = try translate(loweredFunctionSignature: loweredSignature, methodName: javaName)

      // Closures.
      var funcTypes: [TranslatedFunctionType] = []
      for (idx, param) in decl.functionSignature.parameters.enumerated() {
        switch param.type {
        case .function(let funcTy):
          let paramName = param.parameterName ?? "_\(idx)"
          guard case .function( let cdeclTy)  = loweredSignature.parameters[idx].cdeclParameters[0].type else {
            preconditionFailure("closure parameter wasn't lowered to a function type; \(funcTy)")
          }
          let translatedClosure = try translateFunctionType(name: paramName, swiftType: funcTy, cdeclType: cdeclTy)
          funcTypes.append(translatedClosure)
        case .tuple:
          // TODO: Implement
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
        outParameters: [],
        conversion: .placeholder
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
          javaParameters: [
            JavaParameter(name: parameterName, type: cType.javaType)
          ],
          conversion: .placeholder
        )
      }

      switch type {
      case .nominal(let nominal):
        if let knownType = nominal.nominalTypeDecl.knownStandardLibraryType {
          switch knownType {
          case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
            return TranslatedParameter(
              javaParameters: [
                JavaParameter(name: parameterName, type: .javaForeignMemorySegment)
              ],
              conversion: .method(
                .explodedName(component: "pointer"),
                methodName: "reinterpret",
                arguments: [
                  .explodedName(component: "count")
                ],
                withArena: false
              )
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
      if case .instance(let swiftSelf) = swiftSignature.selfParameter {
        selfParameter = try self.translate(
          swiftParam: swiftSelf,
          loweredParam: loweredFunctionSignature.selfParameter!,
          methodName: methodName,
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
            methodName: methodName,
            parameterName: parameterName
          )
        }

      // Result.
      let result = try self.translate(
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
    func translate(
      swiftParam: SwiftParameter,
      loweredParam: LoweredParameter,
      methodName: String,
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
              name: parameterName, type: javaType
            )
          ],
          conversion: .placeholder
        )
      }

      switch swiftType {
      case .metatype:
        // Metatype are expressed as 'org.swift.swiftkit.SwiftAnyType'
        return TranslatedParameter(
          javaParameters: [
            JavaParameter(
              name: parameterName, type: JavaType.class(package: "org.swift.swiftkit.ffm", name: "SwiftAnyType"))
          ],
          conversion: .swiftValueSelfSegment(.placeholder)
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

          case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
            return TranslatedParameter(
              javaParameters: [
                JavaParameter(name: parameterName, type: .javaForeignMemorySegment),
              ],
              conversion: .commaSeparated([
                .placeholder,
                .method(.placeholder, methodName: "byteSize", arguments: [], withArena: false)
              ])
            )

          case .string:
            return TranslatedParameter(
              javaParameters: [
                JavaParameter(
                  name: parameterName, type: .javaLangString
                )
              ],
              conversion: .call(.placeholder, function: "SwiftRuntime.toCString", withArena: true)
            )

          case .data:
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
          javaParameters: [
            JavaParameter(
              name: parameterName, type: try translate(swiftType: swiftType)
            )
          ],
          conversion: .swiftValueSelfSegment(.placeholder)
        )

      case .tuple:
        // TODO: Implement.
        throw JavaTranslationError.unhandledType(swiftType)

      case .function:
        return TranslatedParameter(
          javaParameters: [
            JavaParameter(
              name: parameterName, type: JavaType.class(package: nil, name: "\(methodName).\(parameterName)"))
          ],
          conversion: .call(.placeholder, function: "\(methodName).$toUpcallStub", withArena: true)
        )

      case .optional:
        throw JavaTranslationError.unhandledType(swiftType)
      }
    }

    /// Translate a Swift API result to the user-facing Java API result.
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
          conversion: .placeholder
        )
      }

      switch swiftType {
      case .metatype(_):
        // Metatype are expressed as 'org.swift.swiftkit.SwiftAnyType'
        let javaType = JavaType.class(package: "org.swift.swiftkit.ffm", name: "SwiftAnyType")
        return TranslatedResult(
          javaResultType: javaType,
          outParameters: [],
          conversion: .construct(.placeholder, javaType)
        )

      case .nominal(let swiftNominalType):
        if let knownType = swiftNominalType.nominalTypeDecl.knownStandardLibraryType {
          switch knownType {
          case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
            return TranslatedResult(
              javaResultType: .javaForeignMemorySegment,
              outParameters: [
                JavaParameter(name: "pointer", type: .javaForeignMemorySegment),
                JavaParameter(name: "count", type: .long),
              ],
              conversion: .method(
                .readMemorySegment(.explodedName(component: "pointer"), as: .javaForeignMemorySegment),
                methodName: "reinterpret",
                arguments: [
                  .readMemorySegment(.explodedName(component: "count"), as: .long),
                ],
                withArena: false
              )
            )

          case .data:
            break

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
            JavaParameter(name: "", type: javaType)
          ],
          conversion: .constructSwiftValue(.placeholder, javaType)
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
    // The input
    case placeholder

    // The input exploded into components.
    case explodedName(component: String)

    // A fixed value
    case constant(String)

    // 'value.$memorySegment()'
    indirect case swiftValueSelfSegment(JavaConversionStep)

    // call specified function using the placeholder as arguments.
    // If `withArena` is true, `arena$` argument is added.
    indirect case call(JavaConversionStep, function: String, withArena: Bool)

    // Apply a method on the placeholder.
    // If `withArena` is true, `arena$` argument is added.
    indirect case method(JavaConversionStep, methodName: String, arguments: [JavaConversionStep] = [], withArena: Bool)

    // Call 'new \(Type)(\(placeholder), swiftArena$)'.
    indirect case constructSwiftValue(JavaConversionStep, JavaType)

    // Construct the type using the placeholder as arguments.
    indirect case construct(JavaConversionStep, JavaType)

    // Casting the placeholder to the certain type.
    indirect case cast(JavaConversionStep, JavaType)

    // Convert the results of the inner steps to a comma separated list.
    indirect case commaSeparated([JavaConversionStep])

    // Refer an exploded argument suffixed with `_\(name)`.
    indirect case readMemorySegment(JavaConversionStep, as: JavaType)

    var isPlaceholder: Bool {
      return if case .placeholder = self { true } else { false }
    }
  }
}


extension FFMSwift2JavaGenerator.TranslatedFunctionSignature {
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
  case inoutNotSupported(SwiftType, file: String = #file, line: Int = #line)
  case unhandledType(SwiftType, file: String = #file, line: Int = #line)
}
