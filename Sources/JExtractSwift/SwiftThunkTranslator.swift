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

  func renderGlobalThunks() -> [DeclSyntax] {
    var decls: [DeclSyntax] = []

    for decl in st.importedGlobalFuncs {
      decls.append(contentsOf: render(forFunc: decl))
    }

    return decls
  }

  /// Render all the thunks that make Swift methods accessible to Java.
  func renderThunks(forType nominal: ImportedNominalType) -> [DeclSyntax] {
    var decls: [DeclSyntax] = []
    decls.reserveCapacity(nominal.initializers.count + nominal.methods.count)

    decls.append(renderSwiftTypeAccessor(nominal))

    for decl in nominal.initializers {
      decls.append(contentsOf: renderSwiftInitAccessor(decl))
    }

    for decl in nominal.methods {
      decls.append(contentsOf: render(forFunc: decl))
    }

// TODO: handle variables
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
      public func \(raw: funcName)() -> UnsafeMutableRawPointer /* Any.Type */ {
        return unsafeBitCast(\(raw: nominal.swiftTypeName).self, to: UnsafeMutableRawPointer.self)
      }
      """
  }

  func renderSwiftInitAccessor(_ function: ImportedFunc) -> [DeclSyntax] {
    guard let parent = function.parent else {
      fatalError("Cannot render initializer accessor if init function has no parent! Was: \(function)")
    }

    let thunkName = self.st.thunkNameRegistry.functionThunkName(
      module: st.swiftModuleName, decl: function)

    return
      [
        """
        @_cdecl("\(raw: thunkName)")
        public func \(raw: thunkName)(\(raw: st.renderSwiftParamDecls(function, paramPassingStyle: nil))) -> UnsafeMutableRawPointer /* \(raw: parent.swiftTypeName) */ {
          let _self = \(raw: parent.swiftTypeName)(\(raw: st.renderForwardSwiftParams(function, paramPassingStyle: nil)))
          let self$ = unsafeBitCast(_self, to: UnsafeMutableRawPointer.self)
          return _swiftjava_swift_retain(object: self$)
        }
        """
      ]
  }

  func render(forFunc decl: ImportedFunc) -> [DeclSyntax] {
    st.log.trace("Rendering thunks for: \(decl.baseIdentifier)")
    let thunkName = st.thunkNameRegistry.functionThunkName(module: st.swiftModuleName, decl: decl)

    let returnArrowTy =
      if decl.returnType.cCompatibleJavaMemoryLayout == .primitive(.void) {
        "/* \(decl.returnType.swiftTypeName) */"
      } else {
        "-> \(decl.returnType.cCompatibleSwiftType) /* \(decl.returnType.swiftTypeName) */"
      }
    
    // Do we need to pass a self parameter?
    let paramPassingStyle: SelfParameterVariant?
    let callBase: String
    let callBaseDot: String
      if let parent = decl.parent {
        paramPassingStyle = .swiftThunkSelf
        callBase = "let self$ = unsafeBitCast(_self, to: \(parent.originalSwiftType).self)"
        callBaseDot = "self$."
      } else {
        paramPassingStyle = nil
        callBase = ""
        callBaseDot = ""
      }

    // FIXME: handle in thunk: errors

    let returnStatement: String
    if decl.returnType.javaType.isString {
      returnStatement =
        """
        let adaptedReturnValue = fatalError("Not implemented: adapting return types in Swift thunks")
        return adaptedReturnValue
        """
    } else {
      returnStatement = "return returnValue"
    }

    let declParams = st.renderSwiftParamDecls(
      decl,
      paramPassingStyle: paramPassingStyle,
      style: .cDeclThunk
    )
    return
      [
        """
        @_cdecl("\(raw: thunkName)")
        public func \(raw: thunkName)(\(raw: declParams)) \(raw: returnArrowTy) {
          \(raw: adaptArgumentsInThunk(decl))
          \(raw: callBase)
          let returnValue = \(raw: callBaseDot)\(raw: decl.baseIdentifier)(\(raw: st.renderForwardSwiftParams(decl, paramPassingStyle: paramPassingStyle)))
          \(raw: returnStatement)
        }
        """
      ]
  }
  
  func adaptArgumentsInThunk(_ decl: ImportedFunc) -> String {
    var lines: [String] = []
    for p in decl.parameters {
      if p.type.javaType.isString {
        // FIXME: is there a way we can avoid the copying here?
        let adaptedType =
          """
          let \(p.effectiveValueName) = String(cString: \(p.effectiveValueName))
          """
          
        lines += [adaptedType]
      }
    }
    
    return lines.joined(separator: "\n")
  }
}
