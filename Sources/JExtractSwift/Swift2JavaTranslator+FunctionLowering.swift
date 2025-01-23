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
    case .function, .metatype, .optional:
      throw LoweringError.unhandledType(type)

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
      case .actor, .class: loweringStep = .passDirectly(parameterName)
      case .enum, .struct, .protocol: loweringStep = .passIndirectly(parameterName)
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
        cdeclToOriginal: .tuplify(parameterNames.map { .passDirectly($0) }),
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
      // FIXME: Generic arguments, ugh
      cdeclToOriginal = .suffixed(
        .passDirectly(parameterName),
        ".assumingMemoryBound(to: \(nominal.genericArguments![0]).self)"
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
                 argument: .suffixed(
                    .passDirectly(parameterName + "_pointer"),
                                ".assumingMemoryBound(to: \(nominal.genericArguments![0]).self")),
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

/// How to lower the Swift parameter
enum LoweringStep: Equatable {
  case passDirectly(String)
  case passIndirectly(String)
  indirect case suffixed(LoweringStep, String)
  case initialize(SwiftType, arguments: [LabeledArgument<LoweringStep>])
  case tuplify([LoweringStep])
}

struct LoweredParameters: Equatable {
  /// The steps needed to get from the @_cdecl parameter to the original function
  /// parameter.
  var cdeclToOriginal: LoweringStep

  /// The lowering of the parameters at the C level in Swift.
  var cdeclParameters: [SwiftParameter]

  /// The lowerung of the parmaeters at the C level as expressed for Java's
  /// foreign function and memory interface.
  ///
  /// The elements in this array match up with those of 'cdeclParameters'.
  var javaFFMParameters: [ForeignValueLayout]
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
