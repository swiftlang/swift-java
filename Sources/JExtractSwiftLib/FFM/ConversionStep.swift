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

import SwiftSyntax
import SwiftSyntaxBuilder

/// Describes the transformation needed to take the parameters of a thunk
/// and map them to the corresponding parameter (or result value) of the
/// original function.
enum ConversionStep: Equatable {
  /// The value being lowered.
  case placeholder

  /// A reference to a component in a value that has been exploded, such as
  /// a tuple element or part of a buffer pointer.
  indirect case explodedComponent(ConversionStep, component: String)

  /// Cast the pointer described by the lowering step to the given
  /// Swift type using `unsafeBitCast(_:to:)`.
  indirect case unsafeCastPointer(ConversionStep, swiftType: SwiftType)

  /// Assume at the untyped pointer described by the lowering step to the
  /// given type, using `assumingMemoryBound(to:).`
  indirect case typedPointer(ConversionStep, swiftType: SwiftType)

  /// The thing to which the pointer typed, which is the `pointee` property
  /// of the `Unsafe(Mutable)Pointer` types in Swift.
  indirect case pointee(ConversionStep)

  /// Initialize a value of the given Swift type with the set of labeled
  /// arguments.
  case initialize(SwiftType, arguments: [LabeledArgument<ConversionStep>])

  /// Produce a tuple with the given elements.
  ///
  /// This is used for exploding Swift tuple arguments into multiple
  /// elements, recursively. Note that this always produces unlabeled
  /// tuples, which Swift will convert to the labeled tuple form.
  case tuplify([ConversionStep])

  /// Initialize mutable raw pointer with a typed value.
  indirect case populatePointer(name: String, assumingType: SwiftType? = nil, to: ConversionStep)

  /// Perform multiple conversions for each tuple input elements, but discard the result.
  case tupleExplode([ConversionStep], name: String?)

  /// Perform multiple conversions using the same input.
  case aggregate([ConversionStep], name: String?)

  indirect case member(ConversionStep, member: String)

  /// Count the number of times that the placeholder occurs within this
  /// conversion step.
  var placeholderCount: Int {
    switch self {
    case .explodedComponent(let inner, component: _),
        .pointee(let inner),
        .typedPointer(let inner, swiftType: _),
        .unsafeCastPointer(let inner, swiftType: _),
        .populatePointer(name: _, assumingType: _, to: let inner),
        .member(let inner, member: _):
      inner.placeholderCount
    case .initialize(_, arguments: let arguments):
      arguments.reduce(0) { $0 + $1.argument.placeholderCount }
    case .placeholder, .tupleExplode:
      1
    case .tuplify(let elements), .aggregate(let elements, _):
      elements.reduce(0) { $0 + $1.placeholderCount }
    }
  }

  /// Convert the conversion step into an expression with the given
  /// value as the placeholder value in the expression.
  func asExprSyntax(placeholder: String, bodyItems: inout [CodeBlockItemSyntax]) -> ExprSyntax? {
    switch self {
    case .placeholder:
      return "\(raw: placeholder)"

    case .explodedComponent(let step, component: let component):
      return step.asExprSyntax(placeholder: "\(placeholder)_\(component)", bodyItems: &bodyItems)

    case .unsafeCastPointer(let step, swiftType: let swiftType):
      let untypedExpr = step.asExprSyntax(placeholder: placeholder, bodyItems: &bodyItems)
      return "unsafeBitCast(\(untypedExpr), to: \(swiftType.metatypeReferenceExprSyntax))"

    case .typedPointer(let step, swiftType: let type):
      let untypedExpr = step.asExprSyntax(placeholder: placeholder, bodyItems: &bodyItems)
      return "\(untypedExpr).assumingMemoryBound(to: \(type.metatypeReferenceExprSyntax))"

    case .pointee(let step):
      let untypedExpr = step.asExprSyntax(placeholder: placeholder, bodyItems: &bodyItems)
      return "\(untypedExpr).pointee"

    case .initialize(let type, arguments: let arguments):
      let renderedArguments: [String] = arguments.map { labeledArgument in
        let argExpr = labeledArgument.argument.asExprSyntax(placeholder: placeholder, bodyItems: &bodyItems)
        return LabeledExprSyntax(label: labeledArgument.label, expression: argExpr!).description
      }

      // FIXME: Should be able to use structured initializers here instead
      // of splatting out text.
      let renderedArgumentList = renderedArguments.joined(separator: ", ")
      return "\(raw: type.description)(\(raw: renderedArgumentList))"

    case .tuplify(let elements):
      let renderedElements: [String] = elements.enumerated().map { (index, element) in
        element.asExprSyntax(placeholder: "\(placeholder)_\(index)", bodyItems: &bodyItems)!.description
      }

      // FIXME: Should be able to use structured initializers here instead
      // of splatting out text.
      let renderedElementList = renderedElements.joined(separator: ", ")
      return "(\(raw: renderedElementList))"

    case .populatePointer(name: let pointer, assumingType: let type, to: let step):
      let inner = step.asExprSyntax(placeholder: placeholder, bodyItems: &bodyItems)
      let casting = if let type {
        ".assumingMemoryBound(to: \(type.metatypeReferenceExprSyntax))"
      } else {
        ""
      }
      return "\(raw: pointer)\(raw: casting).initialize(to: \(inner))"

    case .tupleExplode(let steps, let name):
      let toExplode: String
      if let name {
        bodyItems.append("let \(raw: name) = \(raw: placeholder)")
        toExplode = name
      } else {
        toExplode = placeholder
      }
      for (i, step) in steps.enumerated() {
        if let result = step.asExprSyntax(placeholder: "\(toExplode).\(i)", bodyItems: &bodyItems) {
          bodyItems.append(CodeBlockItemSyntax(item: .expr(result)))
        }
      }
      return nil

    case .member(let step, let member):
      let inner = step.asExprSyntax(placeholder: placeholder, bodyItems: &bodyItems)
      return "\(inner).\(raw: member)"

    case .aggregate(let steps, let name):
      let toExplode: String
      if let name {
        bodyItems.append("let \(raw: name) = \(raw: placeholder)")
        toExplode = name
      } else {
        toExplode = placeholder
      }
      for step in steps {
        if let result = step.asExprSyntax(placeholder: toExplode, bodyItems: &bodyItems) {
          bodyItems.append(CodeBlockItemSyntax(item: .expr(result)))
        }
      }
      return nil
    }
  }
}

struct LabeledArgument<Element> {
  var label: String?
  var argument: Element
}

extension LabeledArgument: Equatable where Element: Equatable { }
