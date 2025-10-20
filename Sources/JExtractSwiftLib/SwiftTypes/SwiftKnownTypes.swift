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

struct SwiftKnownTypes {
  private let symbolTable: SwiftSymbolTable

  init(symbolTable: SwiftSymbolTable) {
    self.symbolTable = symbolTable
  }

  var bool: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.bool])) }
  var int: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int])) }
  var uint: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint])) }
  var int8: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int8])) }
  var uint8: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint8])) }
  var int16: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int16])) }
  var uint16: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint16])) }
  var int32: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int32])) }
  var uint32: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint32])) }
  var int64: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.int64])) }
  var uint64: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.uint64])) }
  var float: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.float])) }
  var double: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.double])) }
  var unsafeRawPointer: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.unsafeRawPointer])) }
  var unsafeMutableRawPointer: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.unsafeMutableRawPointer])) }

  var foundationDataProtocol: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.foundationDataProtocol])) }
  var foundationData: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.foundationData])) }
  var essentialsDataProtocol: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.essentialsDataProtocol])) }
  var essentialsData: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: symbolTable[.essentialsData])) }

  func unsafePointer(_ pointeeType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.unsafePointer],
        genericArguments: [pointeeType]
      )
    )
  }

  func unsafeMutablePointer(_ pointeeType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.unsafeMutablePointer],
        genericArguments: [pointeeType]
      )
    )
  }

  func unsafeBufferPointer(_ elementType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.unsafeBufferPointer],
        genericArguments: [elementType]
      )
    )
  }

  func unsafeMutableBufferPointer(_ elementType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: symbolTable[.unsafeMutableBufferPointer],
        genericArguments: [elementType]
      )
    )
  }

  /// Returns the known representative concrete type if there is one for the
  /// given protocol kind. E.g. `String` for `StringProtocol`
  func representativeType(of knownProtocol: SwiftKnownTypeDeclKind) -> SwiftType? {
    switch knownProtocol {
    case .foundationDataProtocol: return self.foundationData
    case .essentialsDataProtocol: return self.essentialsData
    default: return nil
    }
  }
}
