//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import SwiftBasicFormat
import SwiftParser
import SwiftSyntax

struct SwiftThunkTranslator {

  let st: Swift2JavaTranslator

  init(_ st: Swift2JavaTranslator) {
    self.st = st
  }

  func render(forType nominal: ImportedNominalType) -> [DeclSyntax] {
    var decls: [DeclSyntax] = []
    decls.reserveCapacity(nominal.methods.count)

    decls.append(renderSwiftTypeAccessor(nominal))

    for method in nominal.methods {
      decls.append(contentsOf: render(forFunc: method))
    }
    for v in nominal.variables {
      if let acc = v.accessorFunc(kind: .get) {
        decls.append(contentsOf: render(forFunc: acc))
      }
      if let acc = v.accessorFunc(kind: .set) {
        decls.append(contentsOf: render(forFunc: acc))
      }
    }

    return decls
  }

  /// Accessor to get the `T.self` of the Swift type, without having to rely on mangled name lookups.
  func renderSwiftTypeAccessor(_ nominal: ImportedNominalType) -> DeclSyntax {
    let funcName = SwiftKitPrinting.Names.getType(
      module: st.swiftModuleName,
      nominal: nominal)

    return
      """
      @_cdecl("\(raw: funcName)")
      public func \(raw: funcName)() -> Any /* Any.Type */ {
        \(raw: nominal.swiftTypeName).self
      }
      """
  }

  func render(forFunc decl: ImportedFunc) -> [DeclSyntax] {
    let decl: DeclSyntax =
      """
      \(decl.swiftDecl)
      """

    return [decl]
  }
}
