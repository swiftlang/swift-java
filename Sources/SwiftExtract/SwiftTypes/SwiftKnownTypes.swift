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

public struct SwiftKnownTypes {
  private let symbolTable: SwiftSymbolTable

  public init(symbolTable: SwiftSymbolTable) {
    self.symbolTable = symbolTable
  }

  public var bool: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.bool])) }
  public var int: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int])) }
  public var uint: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint])) }
  public var int8: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int8])) }
  public var uint8: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint8])) }
  public var int16: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int16])) }
  public var uint16: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint16])) }
  public var int32: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int32])) }
  public var uint32: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint32])) }
  public var int64: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int64])) }
  public var uint64: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint64])) }
  public var float: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.float])) }
  public var double: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.double])) }
  public var unsafeRawPointer: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.unsafeRawPointer])) }
  public var unsafeRawBufferPointer: SwiftType {
    .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.unsafeRawBufferPointer]))
  }
  public var unsafeMutableRawPointer: SwiftType {
    .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.unsafeMutableRawPointer]))
  }
  public var string: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.string])) }

  public var foundationDataProtocol: SwiftType {
    .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.foundationDataProtocol]))
  }
  public var foundationData: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.foundationData])) }
  public var essentialsDataProtocol: SwiftType {
    .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.essentialsDataProtocol]))
  }
  public var essentialsData: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.essentialsData])) }
  public var foundationUUID: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.foundationUUID])) }
  public var essentialsUUID: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.essentialsUUID])) }
  public var foundationURL: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.foundationURL])) }
  public var essentialsURL: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.essentialsURL])) }

  /// `(UnsafeRawPointer, Long) -> ()` function type.
  ///
  /// Commonly used to initialize a buffer using the passed bytes and length.
  public var functionInitializeByteBuffer: SwiftType {
    .function(
      SwiftFunctionType(
        convention: .c,
        parameters: [
          SwiftParameter(convention: .byValue, parameterName: nil, type: self.unsafeRawPointer), // array base pointer
          SwiftParameter(convention: .byValue, parameterName: nil, type: self.int), // array length
        ],
        resultType: .void
      )
    )
  }

  public func unsafePointer(_ pointeeType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.unsafePointer],
        genericArguments: [pointeeType]
      )
    )
  }

  public func unsafeMutablePointer(_ pointeeType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.unsafeMutablePointer],
        genericArguments: [pointeeType]
      )
    )
  }

  public func unsafeBufferPointer(_ elementType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.unsafeBufferPointer],
        genericArguments: [elementType]
      )
    )
  }

  public func unsafeMutableBufferPointer(_ elementType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.unsafeMutableBufferPointer],
        genericArguments: [elementType]
      )
    )
  }

  public func optionalSugar(_ wrappedType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        sugarName: .optional,
        nominalTypeDecl: symbolTable[.optional],
        genericArguments: [wrappedType]
      )
    )
  }

  public func arraySugar(_ elementType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        sugarName: .array,
        nominalTypeDecl: symbolTable[.array],
        genericArguments: [elementType]
      )
    )
  }

  public func dictionarySugar(_ keyType: SwiftType, _ valueType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        sugarName: .dictionary,
        nominalTypeDecl: symbolTable[.dictionary],
        genericArguments: [keyType, valueType]
      )
    )
  }

  public func set(_ elementType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.set],
        genericArguments: [elementType]
      )
    )
  }

  /// Returns the known representative concrete type if there is one for the
  /// given protocol kind. E.g. `Data` for `DataProtocol`
  public func representativeType(of knownProtocol: SwiftKnownTypeDeclKind) -> SwiftType? {
    guard let kind = Self.representativeType(of: knownProtocol) else { return nil }
    return .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[kind]))
  }

  /// Returns the representative concrete type kind for a protocol, if one exists
  public static func representativeType(of knownProtocol: SwiftKnownTypeDeclKind) -> SwiftKnownTypeDeclKind? {
    switch knownProtocol {
    case .foundationDataProtocol: return .foundationData
    case .essentialsDataProtocol: return .essentialsData
    default: return nil
    }
  }
}
