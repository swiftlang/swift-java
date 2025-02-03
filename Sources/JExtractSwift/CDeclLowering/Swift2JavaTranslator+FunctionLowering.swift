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
import SwiftSyntax

extension Swift2JavaTranslator {
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
      enclosingType: try enclosingType.map { try SwiftType($0, symbolTable: symbolTable) },
      symbolTable: symbolTable
    )

    return try lowerFunctionSignature(signature)
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
      enclosingType: try enclosingType.map { try SwiftType($0, symbolTable: symbolTable) },
      symbolTable: symbolTable
    )

    return try lowerFunctionSignature(signature)
  }
  /// Lower the given Swift function signature to a Swift @_cdecl function signature,
  /// which is C compatible, and the corresponding Java method signature.
  ///
  /// Throws an error if this function cannot be lowered for any reason.
  func lowerFunctionSignature(
    _ signature: SwiftFunctionSignature
  ) throws -> LoweredFunctionSignature {
    // Lower all of the parameters.
    let loweredParameters = try signature.parameters.enumerated().map { (index, param) in
      try lowerParameter(
        param.type,
        convention: param.convention,
        parameterName: param.parameterName ?? "_\(index)"
      )
    }

    // Lower the result.
    var loweredResult = try lowerParameter(
      signature.result.type,
      convention: .byValue,
      parameterName: "_result"
    )

    // If the result type doesn't lower to either empty (void) or a single
    // result, make it indirect.
    let indirectResult: Bool
    if loweredResult.cdeclParameters.count == 0 {
      // void result type
      indirectResult = false
    } else if loweredResult.cdeclParameters.count == 1,
              loweredResult.cdeclParameters[0].canBeDirectReturn {
      // Primitive result type
      indirectResult = false
    } else {
      loweredResult = try lowerParameter(
        signature.result.type,
        convention: .inout,
        parameterName: "_result"
      )
      indirectResult = true
    }

    // Lower the self parameter.
    let loweredSelf = try signature.selfParameter.flatMap { selfParameter in
      switch selfParameter {
      case .instance(let selfParameter):
        try lowerParameter(
          selfParameter.type,
          convention: selfParameter.convention,
          parameterName: selfParameter.parameterName ?? "self"
        )
      case .initializer, .staticMethod:
        nil
      }
    }

    // Collect all of the lowered parameters for the @_cdecl function.
    var allLoweredParameters: [LoweredParameters] = []
    var cdeclLoweredParameters: [SwiftParameter] = []
    allLoweredParameters.append(contentsOf: loweredParameters)
    cdeclLoweredParameters.append(
      contentsOf: loweredParameters.flatMap { $0.cdeclParameters }
    )

    let cdeclResult: SwiftResult
    if indirectResult {
      cdeclLoweredParameters.append(
        contentsOf: loweredResult.cdeclParameters
      )
      cdeclResult = .init(convention: .direct, type: .tuple([]))
    } else if loweredResult.cdeclParameters.count == 1,
              let primitiveResult = loweredResult.cdeclParameters.first {
      cdeclResult = .init(convention: .direct, type: primitiveResult.type)
    } else if loweredResult.cdeclParameters.count == 0 {
      cdeclResult = .init(convention: .direct, type: .tuple([]))
    } else {
      fatalError("Improper lowering of result for \(signature)")
    }

    if let loweredSelf {
      allLoweredParameters.append(loweredSelf)
      cdeclLoweredParameters.append(contentsOf: loweredSelf.cdeclParameters)
    }

    let cdeclSignature = SwiftFunctionSignature(
      selfParameter: nil,
      parameters: cdeclLoweredParameters,
      result: cdeclResult
    )

    return LoweredFunctionSignature(
      original: signature,
      cdecl: cdeclSignature,
      parameters: allLoweredParameters,
      result: loweredResult
    )
  }

  func lowerParameter(
    _ type: SwiftType,
    convention: SwiftParameterConvention,
    parameterName: String
  ) throws -> LoweredParameters {
    switch type {
    case .function, .optional:
      throw LoweringError.unhandledType(type)

    case .metatype:
      return LoweredParameters(
        cdeclParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: .nominal(
              SwiftNominalType(
                nominalTypeDecl: swiftStdlibTypes[.unsafeRawPointer]
              )
            ),
            canBeDirectReturn: true
          )
        ]
      )

    case .nominal(let nominal):
      // Types from the Swift standard library that we know about.
      if let knownType = nominal.nominalTypeDecl.knownStandardLibraryType,
         convention != .inout {
        // Swift types that map to primitive types in C. These can be passed
        // through directly.
        if knownType.primitiveCType != nil {
          return LoweredParameters(
            cdeclParameters: [
              SwiftParameter(
                convention: convention,
                parameterName: parameterName,
                type: type,
                canBeDirectReturn: true
              )
            ]
          )
        }

        // Typed pointers are mapped down to their raw forms in cdecl entry
        // points. These can be passed through directly.
        if knownType == .unsafePointer || knownType == .unsafeMutablePointer {
          let isMutable = knownType == .unsafeMutablePointer
          let cdeclPointerType = isMutable
            ? swiftStdlibTypes[.unsafeMutableRawPointer]
            : swiftStdlibTypes[.unsafeRawPointer]
          return LoweredParameters(
            cdeclParameters: [
              SwiftParameter(
                convention: convention,
                parameterName: parameterName + "_pointer",
                type: SwiftType.nominal(
                  SwiftNominalType(nominalTypeDecl: cdeclPointerType)
                ),
                canBeDirectReturn: true
              )
            ]
          )
        }

        // Typed buffer pointers are mapped down to a (pointer, count) pair
        // so those parts can be passed through directly.
        if knownType == .unsafeBufferPointer || knownType == .unsafeMutableBufferPointer {
          let isMutable = knownType == .unsafeMutableBufferPointer
          let cdeclPointerType = isMutable
            ? swiftStdlibTypes[.unsafeMutableRawPointer]
            : swiftStdlibTypes[.unsafeRawPointer]
          return LoweredParameters(
            cdeclParameters: [
              SwiftParameter(
                convention: convention,
                parameterName: parameterName + "_pointer",
                type: SwiftType.nominal(
                  SwiftNominalType(nominalTypeDecl: cdeclPointerType)
                )
              ),
              SwiftParameter(
                convention: convention,
                parameterName: parameterName + "_count",
                type: SwiftType.nominal(
                  SwiftNominalType(nominalTypeDecl: swiftStdlibTypes[.int])
                )
              )
            ]
          )
        }
      }

      // Arbitrary types are lowered to raw pointers that either "are" the
      // reference (for classes and actors) or will point to it.
      let canBeDirectReturn = switch nominal.nominalTypeDecl.kind {
        case .actor, .class: true
        case .enum, .protocol, .struct: false
      }

      let isMutable = (convention == .inout)
      return LoweredParameters(
        cdeclParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: .nominal(
              SwiftNominalType(
                nominalTypeDecl: isMutable
                  ? swiftStdlibTypes[.unsafeMutableRawPointer]
                  : swiftStdlibTypes[.unsafeRawPointer]
              )
            ),
            canBeDirectReturn: canBeDirectReturn
          )
        ]
      )

    case .tuple(let tuple):
      let parameterNames = tuple.indices.map { "\(parameterName)_\($0)" }
      let loweredElements: [LoweredParameters] = try zip(tuple, parameterNames).map { element, name in
        try lowerParameter(element, convention: convention, parameterName: name)
      }
      return LoweredParameters(
        cdeclParameters: loweredElements.flatMap { $0.cdeclParameters }
      )
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

struct LabeledArgument<Element> {
  var label: String?
  var argument: Element
}

extension LabeledArgument: Equatable where Element: Equatable { }


struct LoweredParameters: Equatable {
  /// The lowering of the parameters at the C level in Swift.
  var cdeclParameters: [SwiftParameter]
}

enum LoweringError: Error {
  case inoutNotSupported(SwiftType)
  case unhandledType(SwiftType)
}

@_spi(Testing)
public struct LoweredFunctionSignature: Equatable {
  var original: SwiftFunctionSignature
  public var cdecl: SwiftFunctionSignature

  var parameters: [LoweredParameters]
  var result: LoweredParameters
}

extension LoweredFunctionSignature {
  /// Produce the `@_cdecl` thunk for this lowered function signature that will
  /// call into the original function.
  @_spi(Testing)
  public func cdeclThunk(
    cName: String,
    swiftFunctionName: String,
    stdlibTypes: SwiftStandardLibraryTypes
  ) -> FunctionDeclSyntax {
    var loweredCDecl = cdecl.createFunctionDecl(cName)

    // Add the @_cdecl attribute.
    let cdeclAttribute: AttributeSyntax = "@_cdecl(\(literal: cName))\n"
    loweredCDecl.attributes.append(.attribute(cdeclAttribute))

    // Create the body.

    // Lower "self", if there is one.
    let parametersToLower: ArraySlice<LoweredParameters>
    let cdeclToOriginalSelf: ExprSyntax?
    var initializerType: SwiftType? = nil
    if let originalSelf = original.selfParameter {
      switch originalSelf {
      case .instance(let originalSelfParam):
        // The instance was provided to the cdecl thunk, so convert it to
        // its Swift representation.
        cdeclToOriginalSelf = try! ConversionStep(
          cdeclToSwift: originalSelfParam.type
        ).asExprSyntax(
          isSelf: true,
          placeholder: originalSelfParam.parameterName ?? "self"
        )
        parametersToLower = parameters.dropLast()

      case .staticMethod(let selfType):
        // Static methods use the Swift type as "self", but there is no
        // corresponding cdecl parameter.
        cdeclToOriginalSelf = "\(raw: selfType.description)"
        parametersToLower = parameters[...]

      case .initializer(let selfType):
        // Initializers use the Swift type to create the instance. Save it
        // for later. There is no corresponding cdecl parameter.
        initializerType = selfType
        cdeclToOriginalSelf = nil
        parametersToLower = parameters[...]
      }
    } else {
      cdeclToOriginalSelf = nil
      parametersToLower = parameters[...]
    }

    // Lower the remaining arguments.
    let cdeclToOriginalArguments = parametersToLower.indices.map { index in
      let originalParam = original.parameters[index]
      let cdeclToOriginalArg = try! ConversionStep(
        cdeclToSwift: originalParam.type
      ).asExprSyntax(
        isSelf: false,
        placeholder: originalParam.parameterName ?? "_\(index)"
      )

      if let argumentLabel = originalParam.argumentLabel {
        return "\(argumentLabel): \(cdeclToOriginalArg.description)"
      } else {
        return cdeclToOriginalArg.description
      }
    }

    // Form the call expression.
    let callArguments: ExprSyntax = "(\(raw: cdeclToOriginalArguments.joined(separator: ", ")))"
    let callExpression: ExprSyntax
    if let initializerType {
      callExpression = "\(raw: initializerType.description)\(callArguments)"
    } else if let cdeclToOriginalSelf {
      callExpression = "\(cdeclToOriginalSelf).\(raw: swiftFunctionName)\(callArguments)"
    } else {
      callExpression = "\(raw: swiftFunctionName)\(callArguments)"
    }

    // Handle the return.
    if cdecl.result.type.isVoid && original.result.type.isVoid {
      // Nothing to return.
      loweredCDecl.body = """
        {
          \(callExpression)
        }
        """
    } else {
      // Determine the necessary conversion of the Swift return value to the
      // cdecl return value.
      let resultConversion = try! ConversionStep(
        swiftToCDecl: original.result.type,
        stdlibTypes: stdlibTypes
      )

      var bodyItems: [CodeBlockItemSyntax] = []

      // If the are multiple places in the result conversion that reference
      // the placeholder, capture the result of the call in a local variable.
      // This prevents us from calling the function multiple times.
      let originalResult: ExprSyntax
      if resultConversion.placeholderCount > 1 {
        bodyItems.append("""
            let __swift_result = \(callExpression)
          """
        )
        originalResult = "__swift_result"
      } else {
        originalResult = callExpression
      }

      // FIXME: Check whether there are multiple places in which we reference
      // the placeholder in resultConversion. If so, we should write it into a
      // local let "_resultValue" or similar so we don't call the underlying
      // function multiple times.

      // Convert the result.
      let convertedResult = resultConversion.asExprSyntax(
        isSelf: true,
        placeholder: originalResult.description
      )

      if cdecl.result.type.isVoid {
        // Indirect return. This is a regular return in Swift that turns
        // into an assignment via the indirect parameters. We do a cdeclToSwift
        // conversion on the left-hand side of the tuple to gather all of the
        // indirect output parameters we need to assign to, and the result
        // conversion is the corresponding right-hand side.
        let cdeclParamConversion = try! ConversionStep(
          cdeclToSwift: original.result.type
        )
        let indirectResults = cdeclParamConversion.asExprSyntax(
          isSelf: true,
          placeholder: "_result"
        )
        bodyItems.append("""
            \(indirectResults) = \(convertedResult)
          """
        )
      } else {
        // Direct return. Just convert the expression.
        bodyItems.append("""
            return \(convertedResult)
          """
        )
      }

      loweredCDecl.body = CodeBlockSyntax(
        leftBrace: .leftBraceToken(trailingTrivia: .newline),
        statements: .init(bodyItems.map { $0.with(\.trailingTrivia, .newline) })
      )
    }

    return loweredCDecl
  }
}
