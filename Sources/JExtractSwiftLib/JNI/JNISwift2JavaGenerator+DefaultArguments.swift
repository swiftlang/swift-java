//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftExtract
import SwiftSyntax

// Java has no default arguments, so the JNI output gives a function one overload per trailing
// defaulted parameter a caller may leave out. The overload's thunk calls the function without
// those arguments, and Swift fills in its own defaults: no default expression is translated.

extension AnalysisResult {
  /// Adds an overload for each trailing defaulted parameter a function can be called without, unless
  /// a declared function already has that name and parameter types. Protocol requirements can't have
  /// default arguments, so protocols are left as they are.
  package mutating func expandDefaultArgumentOverloads() {
    self.extractedGlobalFuncs = Self.withDefaultArgumentOverloads(self.extractedGlobalFuncs)

    for type in self.extractedTypes.values where type.swiftNominal.kind != .protocol {
      type.methods = Self.withDefaultArgumentOverloads(type.methods)
      type.initializers = Self.withDefaultArgumentOverloads(type.initializers)
    }
  }

  private static func withDefaultArgumentOverloads(_ funcs: [ExtractedFunc]) -> [ExtractedFunc] {
    var declared = Set(funcs.map(\.overloadKey))
    return funcs.flatMap { function in
      let others = sameNameDeclarations(as: function, extracted: funcs)
      return [function]
        + function.defaultArgumentOverloads().filter { overload in
          // The thunk calls the original with only these arguments, which mustn't be ambiguous.
          let labels = overload.functionSignature.parameters.map { $0.argumentLabel ?? "_" }
          return declared.insert(overload.overloadKey).inserted
            && !others.contains { callableLabelLists(of: $0).contains(labels) }
        }
    }
  }

  /// The other declarations a call to `function` could resolve to: those with its name, exported or not,
  /// in the same declaration list, and the extracted ones elsewhere (such as in other extensions).
  private static func sameNameDeclarations(as function: ExtractedFunc, extracted: [ExtractedFunc]) -> [DeclSyntax] {
    var declarations = extracted.filter { $0 !== function }.map { DeclSyntax(fromProtocol: $0.swiftDecl) }
    if let list = function.swiftDecl.parent?.parent?.as(MemberBlockItemListSyntax.self) {
      declarations += list.map(\.decl)
    } else if let list = function.swiftDecl.parent?.parent?.as(CodeBlockItemListSyntax.self) {
      declarations += list.compactMap { $0.item.as(DeclSyntax.self) }
    }
    let isStatic = isStaticDeclaration(DeclSyntax(fromProtocol: function.swiftDecl))
    var seen: Set<SyntaxIdentifier> = [function.swiftDecl.id]
    return declarations.filter { declaration in
      declarationName(declaration) == function.name && isStaticDeclaration(declaration) == isStatic
        && seen.insert(declaration.id).inserted
    }
  }
}

extension ExtractedFunc {
  /// Overloads that leave out this function's trailing defaulted parameters, longest first.
  ///
  /// A method whose result may need a `SwiftArena` also gets an overload ending in one, which a
  /// Kotlin lambda converts to. So an overload is left out when the parameter after its last one is
  /// a closure and the overload with that closure exists: `f(a, SwiftArena)` would be ambiguous with
  /// `f(a, closure)`.
  func defaultArgumentOverloads() -> [ExtractedFunc] {
    let parameters = functionSignature.parameters
    let mayTakeArena = apiKind == .initializer || Self.resultMayNeedArena(functionSignature.result.type)
    var overloads: [ExtractedFunc] = []
    var count = parameters.count
    var longerOverloadExists = true
    while count > 0, parameters[count - 1].hasDefaultValue {
      count -= 1
      if mayTakeArena, longerOverloadExists, case .function = parameters[count].type {
        longerOverloadExists = false
        continue
      }
      longerOverloadExists = true
      var signature = functionSignature
      signature.parameters = Array(parameters.prefix(count))
      overloads.append(
        ExtractedFunc(
          module: module,
          swiftDecl: swiftDecl,
          name: name,
          apiKind: apiKind,
          functionSignature: signature,
          sourceFilePath: sourceFilePath
        )
      )
    }
    return overloads
  }

  /// Whether a result may be returned through a `SwiftArena`: anything but primitives, strings and
  /// `Void`, or optionals and arrays of them.
  private static func resultMayNeedArena(_ type: SwiftType) -> Bool {
    switch type {
    case .nominal(let nominal):
      switch nominal.asKnownType {
      case .bool, .int, .uint, .int8, .uint8, .int16, .uint16, .int32, .uint32, .int64, .uint64, .float, .double,
        .string:
        return false
      case .optional(let wrapped), .array(let wrapped):
        return resultMayNeedArena(wrapped)
      default:
        return true
      }
    case .tuple(let elements):
      return elements.contains { resultMayNeedArena($0.type) }
    default:
      return true
    }
  }

  /// Identifies an overload by name and parameter types, as Java does.
  fileprivate var overloadKey: String {
    "\(name)(\(functionSignature.parameters.map { "\($0.type)" }.joined(separator: ",")))"
  }
}

private func declarationName(_ declaration: DeclSyntax) -> String? {
  if let function = declaration.as(FunctionDeclSyntax.self) {
    return function.name.text
  }
  return declaration.is(InitializerDeclSyntax.self) ? "init" : nil
}

private func isStaticDeclaration(_ declaration: DeclSyntax) -> Bool {
  declaration.as(FunctionDeclSyntax.self)?.modifiers.contains {
    $0.name.tokenKind == .keyword(.static) || $0.name.tokenKind == .keyword(.class)
  } ?? false
}

/// The argument label lists a call to a function or initializer can use: any parameter with a default
/// value may be left out.
private func callableLabelLists(of declaration: DeclSyntax) -> Set<[String]> {
  let parameters: FunctionParameterListSyntax
  if let function = declaration.as(FunctionDeclSyntax.self) {
    parameters = function.signature.parameterClause.parameters
  } else if let initializer = declaration.as(InitializerDeclSyntax.self) {
    parameters = initializer.signature.parameterClause.parameters
  } else {
    return []
  }
  var lists: Set<[String]> = [[]]
  for parameter in parameters {
    let label = parameter.firstName.tokenKind == .wildcard ? "_" : parameter.firstName.text
    let withParameter = Set(lists.map { $0 + [label] })
    lists = parameter.defaultValue == nil ? withParameter : lists.union(withParameter)
  }
  return lists
}
