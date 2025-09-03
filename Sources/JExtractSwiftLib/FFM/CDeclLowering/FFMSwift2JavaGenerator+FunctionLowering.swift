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

import SwiftSyntax

extension FFMSwift2JavaGenerator {
  /// Lower the given function declaration to a C-compatible entrypoint,
  /// providing all of the mappings between the parameter and result types
  /// of the original function and its `@_cdecl` counterpart.
  @_spi(Testing)
  public func lowerFunctionSignature(
    _ decl: FunctionDeclSyntax,
    enclosingType: TypeSyntax? = nil
  ) throws -> LoweredFunctionSignature {
    let signature = try SwiftFunctionSignature(
      decl,
      enclosingType: try enclosingType.map { try SwiftType($0, lookupContext: lookupContext) },
      lookupContext: lookupContext
    )
    return try CdeclLowering(symbolTable: lookupContext.symbolTable).lowerFunctionSignature(signature)
  }

  /// Lower the given initializer to a C-compatible entrypoint,
  /// providing all of the mappings between the parameter and result types
  /// of the original function and its `@_cdecl` counterpart.
  @_spi(Testing)
  public func lowerFunctionSignature(
    _ decl: InitializerDeclSyntax,
    enclosingType: TypeSyntax? = nil
  ) throws -> LoweredFunctionSignature {
    let signature = try SwiftFunctionSignature(
      decl,
      enclosingType: try enclosingType.map { try SwiftType($0, lookupContext: lookupContext) },
      lookupContext: lookupContext
    )

    return try CdeclLowering(symbolTable: lookupContext.symbolTable).lowerFunctionSignature(signature)
  }

  /// Lower the given variable decl to a C-compatible entrypoint,
  /// providing the mappings between the `self` and value type of the variable
  /// and its `@_cdecl` counterpart.
  @_spi(Testing)
  public func lowerFunctionSignature(
    _ decl: VariableDeclSyntax,
    isSet: Bool,
    enclosingType: TypeSyntax? = nil
  ) throws -> LoweredFunctionSignature? {
    let supportedAccessors = decl.supportedAccessorKinds(binding: decl.bindings.first!)
    guard supportedAccessors.contains(isSet ? .set : .get) else {
      return nil
    }

    let signature = try SwiftFunctionSignature(
      decl,
      isSet: isSet,
      enclosingType: try enclosingType.map { try SwiftType($0, lookupContext: lookupContext) },
      lookupContext: lookupContext
    )
    return try CdeclLowering(symbolTable: lookupContext.symbolTable).lowerFunctionSignature(signature)
  }
}

/// Responsible for lowering Swift API to C API.
struct CdeclLowering {
  var knownTypes: SwiftKnownTypes

  init(knownTypes: SwiftKnownTypes) {
    self.knownTypes = knownTypes
  }

  init(symbolTable: SwiftSymbolTable) {
    self.knownTypes = SwiftKnownTypes(symbolTable: symbolTable)
  }

  /// Lower the given Swift function signature to a Swift @_cdecl function signature,
  /// which is C compatible, and the corresponding Java method signature.
  ///
  /// Throws an error if this function cannot be lowered for any reason.
  func lowerFunctionSignature(
    _ signature: SwiftFunctionSignature
  ) throws -> LoweredFunctionSignature {
    // Lower the self parameter.
    let loweredSelf: LoweredParameter? = switch signature.selfParameter {
    case .instance(let selfParameter):
      try lowerParameter(
        selfParameter.type,
        convention: selfParameter.convention,
        parameterName: selfParameter.parameterName ?? "self",
        genericParameters: signature.genericParameters,
        genericRequirements: signature.genericRequirements
      )
    case nil, .initializer(_), .staticMethod(_):
      nil
    }

    // Lower all of the parameters.
    let loweredParameters = try signature.parameters.enumerated().map { (index, param) in
      return try lowerParameter(
        param.type,
        convention: param.convention,
        parameterName: param.parameterName ?? "_\(index)",
        genericParameters: signature.genericParameters,
        genericRequirements: signature.genericRequirements
      )
    }

    for effect in signature.effectSpecifiers {
      // Prohibit any effects for now.
      throw LoweringError.effectNotSupported(effect)
    }

    // Lower the result.
    let loweredResult = try lowerResult(signature.result.type)

    return LoweredFunctionSignature(
      original: signature,
      selfParameter: loweredSelf,
      parameters: loweredParameters,
      result: loweredResult
    )
  }

  /// Lower a Swift function parameter to cdecl parameters.
  ///
  /// For example, Swift parameter `arg value: inout Int` can be lowered with
  /// `lowerParameter(intTy, .inout, "value")`.
  ///
  /// - Parameters:
  ///   - type: The parameter type.
  ///   - convention: the parameter convention, e.g. `inout`.
  ///   - parameterName: The name of the parameter.
  ///
  func lowerParameter(
    _ type: SwiftType,
    convention: SwiftParameterConvention,
    parameterName: String,
    genericParameters: [SwiftGenericParameterDeclaration],
    genericRequirements: [SwiftGenericRequirement]
  ) throws -> LoweredParameter {
    // If there is a 1:1 mapping between this Swift type and a C type, we just
    // return it.
    if let _ = try? CType(cdeclType: type) {
      if convention != .inout {
        return LoweredParameter(
          cdeclParameters: [SwiftParameter(convention: .byValue, parameterName: parameterName, type: type)],
          conversion: .placeholder
        )
      }
    }

    switch type {
    case .metatype(let instanceType):
      return LoweredParameter(
        cdeclParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: knownTypes.unsafeRawPointer
          )
        ],
        conversion: .unsafeCastPointer(.placeholder, swiftType: instanceType)
      )

    case .nominal(let nominal):
      if let knownType = nominal.nominalTypeDecl.knownTypeKind {
        if convention == .inout {
          // FIXME: Support non-trivial 'inout' for builtin types.
          throw LoweringError.inoutNotSupported(type)
        }
        switch knownType {
        case .unsafePointer, .unsafeMutablePointer:
          guard let genericArgs = type.asNominalType?.genericArguments, genericArgs.count == 1 else {
            throw LoweringError.unhandledType(type)
          }
          // Typed pointers are mapped down to their raw forms in cdecl entry
          // points. These can be passed through directly.
          let isMutable = knownType == .unsafeMutablePointer
          return LoweredParameter(
            cdeclParameters: [
              SwiftParameter(
                convention: .byValue,
                parameterName: parameterName,
                type: isMutable ? knownTypes.unsafeMutableRawPointer : knownTypes.unsafeRawPointer
              )
            ],
            conversion: .typedPointer(.placeholder, swiftType: genericArgs[0])
          )

        case .unsafeBufferPointer, .unsafeMutableBufferPointer:
          guard let genericArgs = nominal.genericArguments, genericArgs.count == 1 else {
            throw LoweringError.unhandledType(type)
          }
          // Typed pointers are lowered to (raw-pointer, count) pair.
          let isMutable = knownType == .unsafeMutableBufferPointer
          return LoweredParameter(
            cdeclParameters: [
              SwiftParameter(
                convention: .byValue, parameterName: "\(parameterName)_pointer",
                type: isMutable ? knownTypes.unsafeMutableRawPointer : knownTypes.unsafeRawPointer
              ),
              SwiftParameter(
                convention: .byValue, parameterName: "\(parameterName)_count",
                type: knownTypes.int
              ),
            ], conversion: .initialize(
              type,
              arguments: [
                LabeledArgument(
                  label: "start",
                  argument: .typedPointer(.explodedComponent(.placeholder, component: "pointer"), swiftType: genericArgs[0])
                ),
                LabeledArgument(
                  label: "count",
                  argument: .explodedComponent(.placeholder, component: "count")
                )
              ]
            )
          )

        case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
          // pointer buffers are lowered to (raw-pointer, count) pair.
          let isMutable = knownType == .unsafeMutableRawBufferPointer
          return LoweredParameter(
            cdeclParameters: [
              SwiftParameter(
                convention: .byValue,
                parameterName: "\(parameterName)_pointer",
                type: .optional(isMutable ? knownTypes.unsafeMutableRawPointer : knownTypes.unsafeRawPointer)
              ),
              SwiftParameter(
                convention: .byValue, parameterName: "\(parameterName)_count",
                type: knownTypes.int
              )
            ],
            conversion: .initialize(
              type,
              arguments: [
                LabeledArgument(
                  label: "start",
                  argument: .explodedComponent(.placeholder, component: "pointer")
                ),
                LabeledArgument(
                  label: "count",
                  argument: .explodedComponent(.placeholder, component: "count")
                )
              ]
            ))

        case .optional:
          guard let genericArgs = nominal.genericArguments, genericArgs.count == 1 else {
            throw LoweringError.unhandledType(type)
          }
          return try lowerOptionalParameter(genericArgs[0], convention: convention, parameterName: parameterName, genericParameters: genericParameters, genericRequirements: genericRequirements)

        case .string:
          // 'String' is passed in by C string. i.e. 'UnsafePointer<Int8>' ('const uint8_t *')
          if knownType == .string {
            return LoweredParameter(
              cdeclParameters: [
                SwiftParameter(
                  convention: .byValue,
                  parameterName: parameterName,
                  type: knownTypes.unsafePointer(knownTypes.int8)
                )
              ],
              conversion: .initialize(type, arguments: [
                LabeledArgument(label: "cString", argument: .placeholder)
              ])
            )
          }

        case .data:
          break

        default:
          // Unreachable? Should be handled by `CType(cdeclType:)` lowering above.
          throw LoweringError.unhandledType(type)
        }
      }

      // Arbitrary nominal types are passed-in as an pointer.
      let isMutable = (convention == .inout)
      return LoweredParameter(
        cdeclParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: isMutable ? knownTypes.unsafeMutableRawPointer : knownTypes.unsafeRawPointer
          ),
        ],
        conversion: .pointee(.typedPointer(.placeholder, swiftType: type))
      )

    case .tuple(let tuple):
      if tuple.count == 1 {
        return try lowerParameter(tuple[0], convention: convention, parameterName: parameterName, genericParameters: genericParameters, genericRequirements: genericRequirements)
      }
      if convention == .inout {
        throw LoweringError.inoutNotSupported(type)
      }
      var parameters: [SwiftParameter] = []
      var conversions: [ConversionStep] = []
      for (idx, element) in tuple.enumerated() {
        // FIXME: Use tuple element label.
        let cdeclName = "\(parameterName)_\(idx)"
        let lowered = try lowerParameter(element, convention: convention, parameterName: cdeclName, genericParameters: genericParameters, genericRequirements: genericRequirements)

        parameters.append(contentsOf: lowered.cdeclParameters)
        conversions.append(lowered.conversion)
      }
      return LoweredParameter(cdeclParameters: parameters, conversion: .tuplify(conversions))

    case .function(let fn):
      let (loweredTy, conversion) = try lowerFunctionType(fn)
      return LoweredParameter(
        cdeclParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: loweredTy
          )
        ],
        conversion: conversion
      )

    case .opaque, .existential, .genericParameter:
      if let concreteTy = type.representativeConcreteTypeIn(knownTypes: knownTypes, genericParameters: genericParameters, genericRequirements: genericRequirements) {
        return try lowerParameter(concreteTy, convention: convention, parameterName: parameterName, genericParameters: genericParameters, genericRequirements: genericRequirements)
      }
      throw LoweringError.unhandledType(type)

    case .optional(let wrapped):
      return try lowerOptionalParameter(wrapped, convention: convention, parameterName: parameterName, genericParameters: genericParameters, genericRequirements: genericRequirements)

    case .composite:
      throw LoweringError.unhandledType(type)
    }
  }

  /// Lower a Swift Optional to cdecl function type.
  ///
  /// - Parameters:
  ///   - fn: the Swift function type to lower.
  func lowerOptionalParameter(
    _ wrappedType: SwiftType,
    convention: SwiftParameterConvention,
    parameterName: String,
    genericParameters: [SwiftGenericParameterDeclaration],
    genericRequirements: [SwiftGenericRequirement]
  ) throws -> LoweredParameter {
    // If there is a 1:1 mapping between this Swift type and a C type, lower it to 'UnsafePointer<T>?'
    if let _ = try? CType(cdeclType: wrappedType) {
      return LoweredParameter(
        cdeclParameters: [
          SwiftParameter(convention: .byValue, parameterName: parameterName, type: .optional(knownTypes.unsafePointer(wrappedType)))
        ],
        conversion: .pointee(.optionalChain(.placeholder))
      )
    }

    switch wrappedType {
    case .nominal(let nominal):
      if let knownType = nominal.nominalTypeDecl.knownTypeKind {
        switch knownType {
        case .data:
          break
        case .unsafeRawPointer, .unsafeMutableRawPointer:
          throw LoweringError.unhandledType(.optional(wrappedType))
        case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
          throw LoweringError.unhandledType(.optional(wrappedType))
        case .unsafePointer, .unsafeMutablePointer:
          throw LoweringError.unhandledType(.optional(wrappedType))
        case .unsafeBufferPointer, .unsafeMutableBufferPointer:
          throw LoweringError.unhandledType(.optional(wrappedType))
        case .void, .string:
          throw LoweringError.unhandledType(.optional(wrappedType))
        case .dataProtocol:
          throw LoweringError.unhandledType(.optional(wrappedType))
        default:
          // Unreachable? Should be handled by `CType(cdeclType:)` lowering above.
          throw LoweringError.unhandledType(.optional(wrappedType))
        }
      }

      // Lower arbitrary nominal to `UnsafeRawPointer?`
      return LoweredParameter(
        cdeclParameters: [
          SwiftParameter(convention: .byValue, parameterName: parameterName, type: .optional(knownTypes.unsafeRawPointer))
        ],
        conversion: .pointee(.typedPointer(.optionalChain(.placeholder), swiftType: wrappedType))
      )

    case .existential, .opaque, .genericParameter:
      if let concreteTy = wrappedType.representativeConcreteTypeIn(knownTypes: knownTypes, genericParameters: genericParameters, genericRequirements: genericRequirements) {
        return try lowerOptionalParameter(concreteTy, convention: convention, parameterName: parameterName, genericParameters: genericParameters, genericRequirements: genericRequirements)
      }
      throw LoweringError.unhandledType(.optional(wrappedType))
      
    case .tuple(let tuple):
      if tuple.count == 1 {
        return try lowerOptionalParameter(tuple[0], convention: convention, parameterName: parameterName, genericParameters: genericParameters, genericRequirements: genericRequirements)
      }
      throw LoweringError.unhandledType(.optional(wrappedType))

    case .function, .metatype, .optional, .composite:
      throw LoweringError.unhandledType(.optional(wrappedType))
    }
  }

  /// Lower a Swift function type (i.e. closure) to cdecl function type.
  ///
  /// - Parameters:
  ///   - fn: the Swift function type to lower.
  func lowerFunctionType(
    _ fn: SwiftFunctionType
  ) throws -> (type: SwiftType, conversion: ConversionStep) {
    var parameters: [SwiftParameter] = []
    var parameterConversions: [ConversionStep] = []

    for (i, parameter) in fn.parameters.enumerated() {
      let parameterName = parameter.parameterName ?? "_\(i)"
      let loweredParam = try lowerClosureParameter(
        parameter.type,
        convention: parameter.convention,
        parameterName: parameterName
      )
      parameters.append(contentsOf: loweredParam.cdeclParameters)
      parameterConversions.append(loweredParam.conversion)
    }

    let resultType: SwiftType
    let resultConversion: ConversionStep
    if let _ = try? CType(cdeclType: fn.resultType) {
      resultType = fn.resultType
      resultConversion = .placeholder
    } else {
      // Non-trivial types are not yet supported.
      throw LoweringError.unhandledType(.function(fn))
    }

    let isCompatibleWithC = parameterConversions.allSatisfy(\.isPlaceholder) && resultConversion.isPlaceholder

    return (
      type: .function(SwiftFunctionType(convention: .c, parameters: parameters, resultType: resultType)),
      conversion: isCompatibleWithC ? .placeholder : .closureLowering(parameters: parameterConversions, result: resultConversion)
    )
  }

  func lowerClosureParameter(
    _ type: SwiftType,
    convention: SwiftParameterConvention,
    parameterName: String
  ) throws -> LoweredParameter {
    // If there is a 1:1 mapping between this Swift type and a C type, we just
    // return it.
    if let _ = try? CType(cdeclType: type) {
      return LoweredParameter(
        cdeclParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: type
          ),
        ],
        conversion: .placeholder
      )
    }
    
    switch type {
    case .nominal(let nominal):
      if let knownType = nominal.nominalTypeDecl.knownTypeKind {
        switch knownType {
        case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
          // pointer buffers are lowered to (raw-pointer, count) pair.
          let isMutable = knownType == .unsafeMutableRawBufferPointer
          return LoweredParameter(
            cdeclParameters: [
              SwiftParameter(
                convention: .byValue,
                parameterName: "\(parameterName)_pointer",
                type: .optional(isMutable ? knownTypes.unsafeMutableRawPointer : knownTypes.unsafeRawPointer)
              ),
              SwiftParameter(
                convention: .byValue,
                parameterName: "\(parameterName)_count",
                type: knownTypes.int
              ),
            ],
            conversion: .tuplify([
              .member(.placeholder, member: "baseAddress"),
              .member(.placeholder, member: "count")
            ])
          )

        case .data:
          break

        default:
          throw LoweringError.unhandledType(type)
        }
      }

      // Custom types are not supported yet.
      throw LoweringError.unhandledType(type)

    case .genericParameter, .function, .metatype, .optional, .tuple, .existential, .opaque, .composite:
      // TODO: Implement
      throw LoweringError.unhandledType(type)
    }
  }

  /// Lower a Swift result type to cdecl out parameters and return type.
  ///
  /// - Parameters:
  ///   - type: The return type.
  ///   - outParameterName: If the type is lowered to a indirect return, this parameter name should be used.
  func lowerResult(
    _ type: SwiftType,
    outParameterName: String = "_result"
  ) throws -> LoweredResult {
    // If there is a 1:1 mapping between this Swift type and a C type, we just
    // return it.
    if let cType = try? CType(cdeclType: type) {
      _ = cType
      return LoweredResult(cdeclResultType: type, cdeclOutParameters: [], conversion: .placeholder);
    }

    switch type {
    case .metatype:
      // 'unsafeBitcast(<result>, to: UnsafeRawPointer.self)' as  'UnsafeRawPointer'
      return LoweredResult(
        cdeclResultType: knownTypes.unsafeRawPointer,
        cdeclOutParameters: [],
        conversion: .unsafeCastPointer(.placeholder, swiftType: knownTypes.unsafeRawPointer)
      )

    case .nominal(let nominal):
      // Types from the Swift standard library that we know about.
      if let knownType = nominal.nominalTypeDecl.knownTypeKind {
        switch knownType {
        case .unsafePointer, .unsafeMutablePointer:
          // Typed pointers are lowered to corresponding raw forms.
          let isMutable = knownType == .unsafeMutablePointer
          let resultType: SwiftType = isMutable ? knownTypes.unsafeMutableRawPointer : knownTypes.unsafeRawPointer
          return LoweredResult(
            cdeclResultType: resultType,
            cdeclOutParameters: [],
            conversion: .initialize(resultType, arguments: [LabeledArgument(argument: .placeholder)])
          )

        case .unsafeBufferPointer, .unsafeMutableBufferPointer:
          // Typed pointers are lowered to (raw-pointer, count) pair.
          let isMutable = knownType == .unsafeMutableBufferPointer
          return try lowerResult(
            .tuple([
              isMutable ? knownTypes.unsafeMutableRawPointer : knownTypes.unsafeRawPointer,
              knownTypes.int
            ]),
            outParameterName: outParameterName
          )

        case .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer:
          // pointer buffers are lowered to (raw-pointer, count) pair.
          let isMutable = knownType == .unsafeMutableRawBufferPointer
          return LoweredResult(
            cdeclResultType: .void,
            cdeclOutParameters: [
              SwiftParameter(
                convention: .byValue,
                parameterName: "\(outParameterName)_pointer",
                type: knownTypes.unsafeMutablePointer(
                  .optional(isMutable ? knownTypes.unsafeMutableRawPointer : knownTypes.unsafeRawPointer)
                )
              ),
              SwiftParameter(
                convention: .byValue,
                parameterName: "\(outParameterName)_count",
                type: knownTypes.unsafeMutablePointer(knownTypes.int)
              ),
            ],
            conversion: .aggregate([
              .populatePointer(
                name: "\(outParameterName)_pointer",
                to: .member(.placeholder, member: "baseAddress")
              ),
              .populatePointer(
                name: "\(outParameterName)_count",
                to: .member(.placeholder, member: "count")
              )
            ], name: outParameterName)
          )

        case .void:
          return LoweredResult(cdeclResultType: .void, cdeclOutParameters: [], conversion: .placeholder)

        case .data:
          break

        case .string, .optional:
          // Not supported at this point.
          throw LoweringError.unhandledType(type)

        default:
          // Unreachable? Should be handled by `CType(cdeclType:)` lowering above.
          throw LoweringError.unhandledType(type)
        }
      }

      // Arbitrary nominal types are indirectly returned.
      return LoweredResult(
        cdeclResultType: .void,
        cdeclOutParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: outParameterName,
            type: knownTypes.unsafeMutableRawPointer
          )
        ],
        conversion: .populatePointer(name: outParameterName, assumingType: type, to: .placeholder)
      )

    case .tuple(let tuple):
      if tuple.count == 1 {
        return try lowerResult(tuple[0], outParameterName: outParameterName)
      }

      var parameters: [SwiftParameter] = []
      var conversions: [ConversionStep] = []
      for (idx, element) in tuple.enumerated() {
        let outName = "\(outParameterName)_\(idx)"
        let lowered = try lowerResult(element, outParameterName: outName)

        // Convert direct return values to typed mutable pointers.
        // E.g. (Int8, Int8) is lowered to '_ result_0: UnsafePointer<Int8>, _ result_1: UnsafePointer<Int8>'
        if !lowered.cdeclResultType.isVoid {
          let parameterName = lowered.cdeclOutParameters.isEmpty ? outName : "\(outName)_return"
          let parameter = SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: knownTypes.unsafeMutablePointer(lowered.cdeclResultType)
          )
          parameters.append(parameter)
          conversions.append(.populatePointer(
            name: parameterName,
            to: lowered.conversion
          ))
        } else {
          // If the element returns void, it should already be a no-result conversion.
          parameters.append(contentsOf: lowered.cdeclOutParameters)
          conversions.append(lowered.conversion)
        }
      }

      return LoweredResult(
        cdeclResultType: .void,
        cdeclOutParameters: parameters,
        conversion: .tupleExplode(conversions, name: outParameterName)
      )

    case .genericParameter, .function, .optional, .existential, .opaque, .composite:
      throw LoweringError.unhandledType(type)
    }
  }

  /// Given a Swift function signature that represents a @_cdecl function,
  /// produce the equivalent C function with the given name.
  ///
  /// Lowering to a @_cdecl function should never produce a
  @_spi(Testing)
  public func cdeclToCFunctionLowering(
    _ cdeclSignature: SwiftFunctionSignature,
    cName: String
  ) -> CFunction {
    return try! CFunction(cdeclSignature: cdeclSignature, cName: cName)
  }
}

/// Represent a Swift parameter in the cdecl thunk.
struct LoweredParameter: Equatable {
  /// Lowered parameters in cdecl thunk.
  /// One Swift parameter can be lowered to multiple parameters.
  /// E.g. 'Data' as (baseAddress, length) pair.
  var cdeclParameters: [SwiftParameter]

  /// Conversion to convert the cdecl thunk parameters to the original Swift argument.
  var conversion: ConversionStep

  init(cdeclParameters: [SwiftParameter], conversion: ConversionStep) {
    self.cdeclParameters = cdeclParameters
    self.conversion = conversion

    assert(cdeclParameters.count == conversion.placeholderCount)
  }
}

struct LoweredResult: Equatable {
  /// The return type of the cdecl thunk.
  var cdeclResultType: SwiftType

  /// Out parameters for populating the returning values.
  ///
  /// Currently, if this is not empty, `cdeclResultType` is `Void`. But the thunk
  /// may utilize both in the future, for example returning the status while
  /// populating the out parameter.
  var cdeclOutParameters: [SwiftParameter]

  /// The conversion from the Swift result to cdecl result.
  var conversion: ConversionStep
}

extension LoweredResult {
  /// Whether the result is returned by populating the passed-in pointer parameters.
  var hasIndirectResult: Bool {
    !cdeclOutParameters.isEmpty
  }
}

@_spi(Testing)
public struct LoweredFunctionSignature: Equatable {
  var original: SwiftFunctionSignature

  var selfParameter: LoweredParameter?
  var parameters: [LoweredParameter]
  var result: LoweredResult

  var allLoweredParameters: [SwiftParameter] {
    var all: [SwiftParameter] = []
    // Original parameters.
    for loweredParam in parameters {
      all += loweredParam.cdeclParameters
    }
    // Self.
    if let selfParameter = self.selfParameter {
      all += selfParameter.cdeclParameters
    }
    // Out parameters.
    all += result.cdeclOutParameters
    return all
  }

  var cdeclSignature: SwiftFunctionSignature {
    SwiftFunctionSignature(
      selfParameter: nil,
      parameters: allLoweredParameters,
      result: SwiftResult(convention: .direct, type: result.cdeclResultType),
      effectSpecifiers: [],
      genericParameters: [],
      genericRequirements: []
    )
  }
}

extension LoweredFunctionSignature {
  /// Produce the `@_cdecl` thunk for this lowered function signature that will
  /// call into the original function.
  package func cdeclThunk(
    cName: String,
    swiftAPIName: String,
    as apiKind: SwiftAPIKind
  ) -> FunctionDeclSyntax {

    let cdeclParams = allLoweredParameters.map(\.description).joined(separator: ", ")
    let returnClause = !result.cdeclResultType.isVoid ? " -> \(result.cdeclResultType.description)" : ""

    var loweredCDecl = try! FunctionDeclSyntax(
      """
      @_cdecl(\(literal: cName))
      public func \(raw: cName)(\(raw: cdeclParams))\(raw: returnClause) {
      }
      """
    )

    var bodyItems: [CodeBlockItemSyntax] = []

    let selfExpr: ExprSyntax?
    switch original.selfParameter {
    case .instance(let swiftSelf):
      // Raise the 'self' from cdecl parameters.
      selfExpr = self.selfParameter!.conversion.asExprSyntax(
        placeholder: swiftSelf.parameterName ?? "self",
        bodyItems: &bodyItems
      )
    case .staticMethod(let selfType), .initializer(let selfType):
      selfExpr = "\(raw: selfType.description)"
    case .none:
      selfExpr = nil
    }

    /// Raise the other parameters.
    let paramExprs = parameters.enumerated().map { idx, param in
      param.conversion.asExprSyntax(
        placeholder: original.parameters[idx].parameterName ?? "_\(idx)",
        bodyItems: &bodyItems
      )!
    }

    // Build callee expression.
    let callee: ExprSyntax = if let selfExpr {
      if case .initializer = apiKind {
        // Don't bother to create explicit ${Self}.init expression.
        selfExpr
      } else {
        ExprSyntax(MemberAccessExprSyntax(base: selfExpr, name: .identifier(swiftAPIName)))
      }
    } else {
      ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(swiftAPIName)))
    }

    // Build the result.
    let resultExpr: ExprSyntax
    switch apiKind {
    case .function, .initializer:
      let arguments = paramExprs.enumerated()
        .map { (i, argument) -> String in
          let argExpr = original.parameters[i].convention == .inout ? "&\(argument)" : argument
          return LabeledExprSyntax(label: original.parameters[i].argumentLabel, expression: argExpr).description
        }
        .joined(separator: ", ")
      resultExpr = "\(callee)(\(raw: arguments))"

    case .getter:
      assert(paramExprs.isEmpty)
      resultExpr = callee

    case .setter:
      assert(paramExprs.count == 1)
      resultExpr = "\(callee) = \(paramExprs[0])"

    case .enumCase:
      // This should not be called, but let's fatalError.
      fatalError("Enum cases are not supported with FFM.")
    }

    // Lower the result.
    if !original.result.type.isVoid {
      let loweredResult: ExprSyntax? = result.conversion.asExprSyntax(
        placeholder: resultExpr.description,
        bodyItems: &bodyItems
      )

      if let loweredResult {
        bodyItems.append(!result.cdeclResultType.isVoid ? "return \(loweredResult)" : "\(loweredResult)")
      }
    } else {
      bodyItems.append("\(resultExpr)")
    }

    loweredCDecl.body!.statements = CodeBlockItemListSyntax {
      bodyItems.map {
        $0.with(\.leadingTrivia, [.newlines(1), .spaces(2)])
      }
    }

    return loweredCDecl
  }

  @_spi(Testing)
  public func cFunctionDecl(cName: String) throws -> CFunction {
    try CFunction(cdeclSignature: self.cdeclSignature, cName: cName)
  }
}

enum LoweringError: Error {
  case inoutNotSupported(SwiftType, file: String = #file, line: Int = #line)
  case unhandledType(SwiftType, file: String = #file, line: Int = #line)
  case effectNotSupported(SwiftEffectSpecifier, file: String = #file, line: Int = #line)
}
