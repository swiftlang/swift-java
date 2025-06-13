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
  private let decls: SwiftStandardLibraryTypeDecls

  init(decls: SwiftStandardLibraryTypeDecls) {
    self.decls = decls
  }

  var bool: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.bool])) }
  var int: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.int])) }
  var uint: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.uint])) }
  var int8: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.int8])) }
  var uint8: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.uint8])) }
  var int16: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.int16])) }
  var uint16: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.uint16])) }
  var int32: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.int32])) }
  var uint32: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.uint32])) }
  var int64: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.int64])) }
  var uint64: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.uint64])) }
  var float: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.float])) }
  var double: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.double])) }
  var unsafeRawPointer: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.unsafeRawPointer])) }
  var unsafeMutableRawPointer: SwiftType { .nominal(SwiftNominalType(nominalTypeDecl: decls[.unsafeMutableRawPointer])) }
  
  func unsafePointer(_ pointeeType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: decls.unsafePointerDecl,
        genericArguments: [pointeeType]
      )
    )
  }

  func unsafeMutablePointer(_ pointeeType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: decls.unsafeMutablePointerDecl,
        genericArguments: [pointeeType]
      )
    )
  }

  func unsafeBufferPointer(_ elementType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: decls.unsafeBufferPointerDecl,
        genericArguments: [elementType]
      )
    )
  }

  func unsafeMutableBufferPointer(_ elementType: SwiftType) -> SwiftType {
    .nominal(
      SwiftNominalType(
        nominalTypeDecl: decls.unsafeMutableBufferPointerDecl,
        genericArguments: [elementType]
      )
    )
  }
}
