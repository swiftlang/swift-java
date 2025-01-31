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

extension SwiftStandardLibraryTypes {
  /// Lower the given Swift type down to a its corresponding C type.
  ///
  /// This operation only supports the subset of Swift types that are
  /// representable in a Swift `@_cdecl` function. If lowering an arbitrary
  /// Swift function, first go through Swift -> cdecl lowering.
  func cdeclToCLowering(_ swiftType: SwiftType) throws -> CType {
    switch swiftType {
    case .nominal(let nominalType):
      if let knownType = self[nominalType.nominalTypeDecl] {
        return try knownType.loweredCType()
      }

      throw CDeclToCLoweringError.invalidNominalType(nominalType.nominalTypeDecl)

    case .function(let functionType):
      switch functionType.convention {
      case .swift:
        throw CDeclToCLoweringError.invalidFunctionConvention(functionType)

      case .c:
        let resultType = try cdeclToCLowering(functionType.resultType)
        let parameterTypes = try functionType.parameters.map { param in
          try cdeclToCLowering(param.type)
        }

        return .function(
          resultType: resultType,
          parameters: parameterTypes,
          variadic: false
        )
      }

    case .tuple([]):
      return .void

    case .metatype, .optional, .tuple:
      throw CDeclToCLoweringError.invalidCDeclType(swiftType)
    }
  }
}

extension KnownStandardLibraryType {
  func loweredCType() throws -> CType {
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
    }
  }
}
enum CDeclToCLoweringError: Error {
  case invalidCDeclType(SwiftType)
  case invalidNominalType(SwiftNominalTypeDeclaration)
  case invalidFunctionConvention(SwiftFunctionType)
}

