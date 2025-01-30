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

  /// Lower the given Swift function signature to a Swift @_cdecl function signature,
  /// which is C compatible, and the corresponding Java method signature.
  ///
  /// Throws an error if this function cannot be lowered for any reason.
  func lowerFunctionSignature(
    _ signature: SwiftFunctionSignature
  ) throws -> LoweredFunctionSignature {
    // Lower all of the parameters.
    let loweredSelf = try signature.selfParameter.map { selfParameter in
      try lowerParameter(
        selfParameter.type,
        convention: selfParameter.convention, parameterName: "self"
      )
    }

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
    // primitive result, make it indirect.
    let indirectResult: Bool
    if !(loweredResult.javaFFMParameters.count == 0 ||
         (loweredResult.javaFFMParameters.count == 1 &&
          loweredResult.javaFFMParameters[0].isPrimitive)) {
      loweredResult = try lowerParameter(
        signature.result.type,
        convention: .inout,
        parameterName: "_result"
      )
      indirectResult = true
    } else {
      indirectResult = false
    }

    // Collect all of the lowered parameters for the @_cdecl function.
    var allLoweredParameters: [LoweredParameters] = []
    var cdeclLoweredParameters: [SwiftParameter] = []
    if let loweredSelf {
      allLoweredParameters.append(loweredSelf)
      cdeclLoweredParameters.append(contentsOf: loweredSelf.cdeclParameters)
    }
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

    let cdeclSignature = SwiftFunctionSignature(
      isStaticOrClass: false,
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

    case .metatype(let instanceType):
      return LoweredParameters(
        cdeclToOriginal: .unsafeCastPointer(
          .passDirectly(parameterName),
          swiftType: instanceType
        ),
        cdeclParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: .nominal(
              SwiftNominalType(
                nominalTypeDecl: swiftStdlibTypes.unsafeRawPointerDecl
              )
            )
          )
        ],
        javaFFMParameters: [.SwiftPointer]
      )

    case .nominal(let nominal):
      // Types from the Swift standard library that we know about.
      if nominal.nominalTypeDecl.moduleName == "Swift",
          nominal.nominalTypeDecl.parent == nil {
        // Primitive types
        if let loweredPrimitive = try lowerParameterPrimitive(nominal, convention: convention, parameterName: parameterName) {
          return loweredPrimitive
        }

        // Swift pointer types.
        if let loweredPointers = try lowerParameterPointers(nominal, convention: convention, parameterName: parameterName) {
          return loweredPointers
        }
      }

      let mutable = (convention == .inout)
      let loweringStep: LoweringStep
      switch nominal.nominalTypeDecl.kind {
      case .actor, .class:
        loweringStep = 
          .unsafeCastPointer(.passDirectly(parameterName), swiftType: type)
      case .enum, .struct, .protocol:
        loweringStep =
          .passIndirectly(.pointee( .typedPointer(.passDirectly(parameterName), swiftType: type)))
      }

      return LoweredParameters(
        cdeclToOriginal: loweringStep,
        cdeclParameters: [
          SwiftParameter(
            convention: .byValue,
            parameterName: parameterName,
            type: .nominal(
              SwiftNominalType(
                nominalTypeDecl: mutable
                  ? swiftStdlibTypes.unsafeMutableRawPointerDecl
                  : swiftStdlibTypes.unsafeRawPointerDecl
              )
            )
          )
        ],
        javaFFMParameters: [.SwiftPointer]
      )

    case .tuple(let tuple):
      let parameterNames = tuple.indices.map { "\(parameterName)_\($0)" }
      let loweredElements: [LoweredParameters] = try zip(tuple, parameterNames).map { element, name in
        try lowerParameter(element, convention: convention, parameterName: name)
      }
      return LoweredParameters(
        cdeclToOriginal: .tuplify(loweredElements.map { $0.cdeclToOriginal }),
        cdeclParameters: loweredElements.flatMap { $0.cdeclParameters },
        javaFFMParameters: loweredElements.flatMap { $0.javaFFMParameters }
      )
    }
  }

  func lowerParameterPrimitive(
    _ nominal: SwiftNominalType,
    convention: SwiftParameterConvention,
    parameterName: String
  ) throws -> LoweredParameters? {
    let nominalName = nominal.nominalTypeDecl.name
    let type = SwiftType.nominal(nominal)

    // Swift types that map directly to Java primitive types.
    if let primitiveType = JavaType(swiftTypeName: nominalName) {
      // We cannot handle inout on primitive types.
      if convention == .inout {
        throw LoweringError.inoutNotSupported(type)
      }

      return LoweredParameters(
        cdeclToOriginal: .passDirectly(parameterName),
        cdeclParameters: [
          SwiftParameter(
            convention: convention,
            parameterName: parameterName,
            type: type
          )
        ],
        javaFFMParameters: [
          ForeignValueLayout(javaType: primitiveType)!
        ]
      )
    }

    // The Swift "Int" type, which maps to whatever the pointer-sized primitive
    // integer type is in Java (int for 32-bit, long for 64-bit).
    if nominalName == "Int" {
      // We cannot handle inout on primitive types.
      if convention == .inout {
        throw LoweringError.inoutNotSupported(type)
      }

      return LoweredParameters(
        cdeclToOriginal: .passDirectly(parameterName),
        cdeclParameters: [
          SwiftParameter(
            convention: convention,
            parameterName: parameterName,
            type: type
          )
        ],
        javaFFMParameters: [
          .SwiftInt
        ]
      )
    }

    return nil
  }

  func lowerParameterPointers(
    _ nominal: SwiftNominalType,
    convention: SwiftParameterConvention,
    parameterName: String
  ) throws -> LoweredParameters? {
    let nominalName = nominal.nominalTypeDecl.name
    let type = SwiftType.nominal(nominal)

    guard let (requiresArgument, mutable, hasCount) = nominalName.isNameOfSwiftPointerType else {
      return nil
    }

    // At the @_cdecl level, make everything a raw pointer.
    let cdeclPointerType = mutable
      ? swiftStdlibTypes.unsafeMutableRawPointerDecl
      : swiftStdlibTypes.unsafeRawPointerDecl
    var cdeclToOriginal: LoweringStep
    switch (requiresArgument, hasCount) {
    case (false, false):
      cdeclToOriginal = .passDirectly(parameterName)

    case (true, false):
      cdeclToOriginal = .typedPointer(
        .passDirectly(parameterName + "_pointer"),
        swiftType: nominal.genericArguments![0]
      )

    case (false, true):
      cdeclToOriginal = .initialize(type, arguments: [
        LabeledArgument(label: "start", argument: .passDirectly(parameterName + "_pointer")),
        LabeledArgument(label: "count", argument: .passDirectly(parameterName + "_count"))
      ])

    case (true, true):
      cdeclToOriginal = .initialize(
        type,
        arguments: [
          LabeledArgument(label: "start",
                 argument: .typedPointer(
                    .passDirectly(parameterName + "_pointer"),
                    swiftType: nominal.genericArguments![0])),
          LabeledArgument(label: "count",
                 argument: .passDirectly(parameterName + "_count"))
        ]
      )
    }

    let lowered: [(SwiftParameter, ForeignValueLayout)]
    if hasCount {
      lowered = [
        (
          SwiftParameter(
            convention: convention,
            parameterName: parameterName + "_pointer",
            type: SwiftType.nominal(
              SwiftNominalType(nominalTypeDecl: cdeclPointerType)
            )
          ),
          .SwiftPointer
        ),
        (
          SwiftParameter(
            convention: convention,
            parameterName: parameterName + "_count",
            type: SwiftType.nominal(
              SwiftNominalType(nominalTypeDecl: swiftStdlibTypes.intDecl)
            )
          ),
          .SwiftInt
         )
      ]
    } else {
      lowered = [
        (
          SwiftParameter(
            convention: convention,
            parameterName: parameterName + "_pointer",
            type: SwiftType.nominal(
              SwiftNominalType(nominalTypeDecl: cdeclPointerType)
            )
          ),
          .SwiftPointer
        ),
      ]
    }

    return LoweredParameters(
      cdeclToOriginal: cdeclToOriginal,
      cdeclParameters: lowered.map(\.0),
      javaFFMParameters: lowered.map(\.1)
    )
  }
}

struct LabeledArgument<Element> {
  var label: String?
  var argument: Element
}

extension LabeledArgument: Equatable where Element: Equatable { }

/// Describes the transformation needed to take the parameters of a thunk
/// and map them to the corresponding parameter (or result value) of the
/// original function.
enum LoweringStep: Equatable {
  /// A direct reference to a parameter of the thunk.
  case passDirectly(String)

  /// Cast the pointer described by the lowering step to the given
  /// Swift type using `unsafeBitCast(_:to:)`.
  indirect case unsafeCastPointer(LoweringStep, swiftType: SwiftType)

  /// Assume at the untyped pointer described by the lowering step to the
  /// given type, using `assumingMemoryBound(to:).`
  indirect case typedPointer(LoweringStep, swiftType: SwiftType)

  /// The thing to which the pointer typed, which is the `pointee` property
  /// of the `Unsafe(Mutable)Pointer` types in Swift.
  indirect case pointee(LoweringStep)

  /// Pass this value indirectly, via & for explicit `inout` parameters.
  indirect case passIndirectly(LoweringStep)

  /// Initialize a value of the given Swift type with the set of labeled
  /// arguments.
  case initialize(SwiftType, arguments: [LabeledArgument<LoweringStep>])

  /// Produce a tuple with the given elements.
  ///
  /// This is used for exploding Swift tuple arguments into multiple
  /// elements, recursively. Note that this always produces unlabeled
  /// tuples, which Swift will convert to the labeled tuple form.
  case tuplify([LoweringStep])
}

struct LoweredParameters: Equatable {
  /// The steps needed to get from the @_cdecl parameters to the original function
  /// parameter.
  var cdeclToOriginal: LoweringStep

  /// The lowering of the parameters at the C level in Swift.
  var cdeclParameters: [SwiftParameter]

  /// The lowering of the parameters at the C level as expressed for Java's
  /// foreign function and memory interface.
  ///
  /// The elements in this array match up with those of 'cdeclParameters'.
  var javaFFMParameters: [ForeignValueLayout]
}

extension LoweredParameters {
  /// Produce an expression that computes the argument for this parameter
  /// when calling the original function from the cdecl entrypoint.
  func cdeclToOriginalArgumentExpr(isSelf: Bool)-> ExprSyntax {
    cdeclToOriginal.asExprSyntax(isSelf: isSelf)
  }
}

extension LoweringStep {
  func asExprSyntax(isSelf: Bool) -> ExprSyntax {
    switch self {
    case .passDirectly(let rawArgument):
      return "\(raw: rawArgument)"

    case .unsafeCastPointer(let step, swiftType: let swiftType):
      let untypedExpr = step.asExprSyntax(isSelf: false)
      return "unsafeBitCast(\(untypedExpr), to: \(swiftType.metatypeReferenceExprSyntax))"

    case .typedPointer(let step, swiftType: let type):
      let untypedExpr = step.asExprSyntax(isSelf: isSelf)
      return "\(untypedExpr).assumingMemoryBound(to: \(type.metatypeReferenceExprSyntax))"

    case .pointee(let step):
      let untypedExpr = step.asExprSyntax(isSelf: isSelf)
      return "\(untypedExpr).pointee"

    case .passIndirectly(let step):
      let innerExpr = step.asExprSyntax(isSelf: false)
      return isSelf ? innerExpr : "&\(innerExpr)"

    case .initialize(let type, arguments: let arguments):
      let renderedArguments: [String] = arguments.map { labeledArgument in
        let renderedArg = labeledArgument.argument.asExprSyntax(isSelf: false)
        if let argmentLabel = labeledArgument.label {
          return "\(argmentLabel): \(renderedArg.description)"
        } else {
          return renderedArg.description
        }
      }

      // FIXME: Should be able to use structured initializers here instead
      // of splatting out text.
      let renderedArgumentList = renderedArguments.joined(separator: ", ")
      return "\(raw: type.description)(\(raw: renderedArgumentList))"

    case .tuplify(let elements):
      let renderedElements: [String] = elements.map { element in
        element.asExprSyntax(isSelf: false).description
      }

      // FIXME: Should be able to use structured initializers here instead
      // of splatting out text.
      let renderedElementList = renderedElements.joined(separator: ", ")
      return "(\(raw: renderedElementList))"
    }
  }
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
  public func cdeclThunk(cName: String, inputFunction: FunctionDeclSyntax) -> FunctionDeclSyntax {
    var loweredCDecl = cdecl.createFunctionDecl(cName)

    // Add the @_cdecl attribute.
    let cdeclAttribute: AttributeSyntax = "@_cdecl(\(literal: cName))\n"
    loweredCDecl.attributes.append(.attribute(cdeclAttribute))

    // Create the body.

    // Lower "self", if there is one.
    let parametersToLower: ArraySlice<LoweredParameters>
    let cdeclToOriginalSelf: ExprSyntax?
    if original.selfParameter != nil {
      cdeclToOriginalSelf = parameters[0].cdeclToOriginalArgumentExpr(isSelf: true)
      parametersToLower = parameters[1...]
    } else {
      cdeclToOriginalSelf = nil
      parametersToLower = parameters[...]
    }

    // Lower the remaining arguments.
    // FIXME: Should be able to use structured initializers here instead
    // of splatting out text.
    let cdeclToOriginalArguments = zip(parametersToLower, original.parameters).map { lowering, originalParam in
      let cdeclToOriginalArg = lowering.cdeclToOriginalArgumentExpr(isSelf: false)
      if let argumentLabel = originalParam.argumentLabel {
        return "\(argumentLabel): \(cdeclToOriginalArg.description)"
      } else {
        return cdeclToOriginalArg.description
      }
    }

    // Form the call expression.
    var callExpression: ExprSyntax = "\(inputFunction.name)(\(raw: cdeclToOriginalArguments.joined(separator: ", ")))"
    if let cdeclToOriginalSelf {
      callExpression = "\(cdeclToOriginalSelf).\(callExpression)"
    }

    // Handle the return.
    if cdecl.result.type.isVoid && original.result.type.isVoid {
      // Nothing to return.
      loweredCDecl.body = """
        {
          \(callExpression)
        }
        """
    } else if cdecl.result.type.isVoid {
      // Indirect return. This is a regular return in Swift that turns
      // into a
      loweredCDecl.body = """
        {
          \(result.cdeclToOriginalArgumentExpr(isSelf: true)) = \(callExpression)
        }
        """
    } else {
      // Direct return.
      loweredCDecl.body = """
        {
          return \(callExpression)
        }
        """
    }

    return loweredCDecl
  }
}
