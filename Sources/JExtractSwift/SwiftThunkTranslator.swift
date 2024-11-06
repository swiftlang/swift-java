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

  /// Render all the thunks that make Swift methods accessible to Java.
  func renderThunks(forType nominal: ImportedNominalType) -> [DeclSyntax] {
    var decls: [DeclSyntax] = []
    decls.reserveCapacity(nominal.initializers.count + nominal.methods.count)

    decls.append(renderSwiftTypeAccessor(nominal))

    for decl in st.importedGlobalFuncs {
      decls.append(contentsOf: render(forFunc: decl))
    }

    for decl in nominal.initializers {
      decls.append(contentsOf: renderSwiftInitAccessor(decl))
    }

    for decl in nominal.methods {
      decls.append(contentsOf: render(forFunc: decl))
    }

//    for v in nominal.variables {
//      if let acc = v.accessorFunc(kind: .get) {
//        decls.append(contentsOf: render(forFunc: acc))
//      }
//      if let acc = v.accessorFunc(kind: .set) {
//        decls.append(contentsOf: render(forFunc: acc))
//      }
//    }

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
        return \(raw: nominal.swiftTypeName).self
      }
      """
  }

  func renderSwiftInitAccessor(_ function: ImportedFunc) -> [DeclSyntax] {
    guard let parent = function.parent else {
      fatalError("Cannot render initializer accessor if init function has no parent! Was: \(function)")
    }

    let funcName = SwiftKitPrinting.Names.functionThunk(
      thunkNameRegistry: &self.st.thunkNameRegistry,
      module: st.swiftModuleName,
      function: function)

    // FIXME: handle in thunk: return types
    // FIXME: handle in thunk: parameters
    // FIXME: handle in thunk: errors
    return
      [
        """
        @_cdecl("\(raw: funcName)")
        public func \(raw: funcName)(\(raw: st.renderSwiftParamDecls(function, paramPassingStyle: nil))) -> Any /* \(raw: parent.swiftTypeName) */ {
          \(raw: parent.swiftTypeName)(\(raw: st.renderForwardSwiftParams(function, paramPassingStyle: nil)))
        }
        """
      ]
  }


  func render(forFunc decl: ImportedFunc) -> [DeclSyntax] {
    st.log.trace("Rendering thunks for: \(decl.baseIdentifier)")
    let funcName = SwiftKitPrinting.Names.functionThunk(
      thunkNameRegistry: &st.thunkNameRegistry,
      module: st.swiftModuleName,
      function: decl)

    // Do we need to pass a self parameter?
    let paramPassingStyle: SelfParameterVariant?
    let callBaseDot: String
      if let parent = decl.parent {
        paramPassingStyle = .swiftThunkSelf
        // TODO: unsafe bitcast
        callBaseDot = "(_self as! \(parent.originalSwiftType))."
      } else {
        paramPassingStyle = nil
        callBaseDot = ""
      }

    return
      [
        """
        @_cdecl("\(raw: funcName)")
        public func \(raw: funcName)(\(raw: st.renderSwiftParamDecls(decl, paramPassingStyle: paramPassingStyle))) -> \(decl.returnType.cCompatibleSwiftType) /* \(raw: decl.returnType.swiftTypeName) */ {
          \(raw: callBaseDot)\(raw: decl.baseIdentifier)(\(raw: st.renderForwardSwiftParams(decl, paramPassingStyle: paramPassingStyle)))
        }
        """
      ]
  }
}