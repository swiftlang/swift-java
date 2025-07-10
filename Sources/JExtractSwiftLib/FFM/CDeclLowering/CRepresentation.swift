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

extension CType {
  /// Lower the given Swift type down to a its corresponding C type.
  ///
  /// This operation only supports the subset of Swift types that are
  /// representable in a Swift `@_cdecl` function, which means that they are
  /// also directly representable in C. If lowering an arbitrary Swift
  /// function, first go through Swift -> cdecl lowering. This function
  /// will throw an error if it encounters a type that is not expressible in
  /// C.
  init(cdeclType: SwiftType) throws {
    switch cdeclType {
    case .nominal(let nominalType):
      if let knownType = nominalType.nominalTypeDecl.knownTypeKind {
        if let primitiveCType = knownType.primitiveCType {
          self = primitiveCType
          return
        }

        switch knownType {
        case .unsafePointer where nominalType.genericArguments?.count == 1:
          self = .pointer(.qualified(const: true, volatile: false, type: try CType(cdeclType: nominalType.genericArguments![0])))
          return
        case .unsafeMutablePointer where nominalType.genericArguments?.count == 1:
          self = .pointer(try CType(cdeclType: nominalType.genericArguments![0]))
          return
        default:
          break
        }
      }

      throw CDeclToCLoweringError.invalidNominalType(nominalType.nominalTypeDecl)

    case .function(let functionType):
      switch functionType.convention {
      case .swift:
        throw CDeclToCLoweringError.invalidFunctionConvention(functionType)

      case .c:
        let resultType = try CType(cdeclType: functionType.resultType)
        let parameterTypes = try functionType.parameters.map { param in
          try CType(cdeclType: param.type)
        }

        self = .function(
          resultType: resultType,
          parameters: parameterTypes,
          variadic: false
        )
      }

    case .tuple([]):
      self = .void

    case .optional(let wrapped) where wrapped.isPointer:
      try self.init(cdeclType: wrapped)

    case .metatype, .optional, .tuple, .opaque, .existential:
      throw CDeclToCLoweringError.invalidCDeclType(cdeclType)
    }
  }
}

extension CFunction {
  /// Produce a C function that represents the given @_cdecl Swift function.
  init(cdeclSignature: SwiftFunctionSignature, cName: String) throws {
    assert(cdeclSignature.selfParameter == nil)

    let cResultType = try CType(cdeclType: cdeclSignature.result.type)
    let cParameters = try cdeclSignature.parameters.map { parameter in
      CParameter(
        name: parameter.parameterName,
        type: try CType(cdeclType: parameter.type).parameterDecay
      )
    }

    self = CFunction(
      resultType: cResultType,
      name: cName,
      parameters: cParameters,
      isVariadic: false
    )
  }
}

enum CDeclToCLoweringError: Error {
  case invalidCDeclType(SwiftType)
  case invalidNominalType(SwiftNominalTypeDeclaration)
  case invalidFunctionConvention(SwiftFunctionType)
}

extension SwiftKnownTypeDeclKind {
  /// Determine the primitive C type that corresponds to this C standard
  /// library type, if there is one.
  var primitiveCType: CType? {
    switch self {
    case .bool: .integral(.bool)
    case .int: .integral(.ptrdiff_t)
    case .uint: .integral(.size_t)
    case .int8: .integral(.signed(bits: 8))
    case .uint8: .integral(.unsigned(bits: 8))
    case .int16: .integral(.signed(bits: 16))
    case .uint16: .integral(.unsigned(bits: 16))
    case .int32: .integral(.signed(bits: 32))
    case .uint32: .integral(.unsigned(bits: 32))
    case .int64: .integral(.signed(bits: 64))
    case .uint64: .integral(.unsigned(bits: 64))
    case .float: .floating(.float)
    case .double: .floating(.double)
    case .unsafeMutableRawPointer: .pointer(.void)
    case .unsafeRawPointer: .pointer(
      .qualified(const: true, volatile: false, type: .void)
    )
    case .void: .void
    case .unsafePointer, .unsafeMutablePointer, .unsafeRawBufferPointer, .unsafeMutableRawBufferPointer, .unsafeBufferPointer, .unsafeMutableBufferPointer, .string, .data, .dataProtocol:
       nil
    }
  }
}
