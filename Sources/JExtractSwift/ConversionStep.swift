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

  /// Pass this value indirectly, via & for explicit `inout` parameters.
  indirect case passIndirectly(ConversionStep)

  /// Initialize a value of the given Swift type with the set of labeled
  /// arguments.
  case initialize(SwiftType, arguments: [LabeledArgument<ConversionStep>])

  /// Produce a tuple with the given elements.
  ///
  /// This is used for exploding Swift tuple arguments into multiple
  /// elements, recursively. Note that this always produces unlabeled
  /// tuples, which Swift will convert to the labeled tuple form.
  case tuplify([ConversionStep])

  /// Convert the conversion step into an expression with the given
  /// value as the placeholder value in the expression.
  func asExprSyntax(isSelf: Bool, placeholder: String) -> ExprSyntax {
    switch self {
    case .placeholder:
      return "\(raw: placeholder)"

    case .explodedComponent(let step, component: let component):
      return step.asExprSyntax(isSelf: false, placeholder: "\(placeholder)_\(component)")

    case .unsafeCastPointer(let step, swiftType: let swiftType):
      let untypedExpr = step.asExprSyntax(isSelf: false, placeholder: placeholder)
      return "unsafeBitCast(\(untypedExpr), to: \(swiftType.metatypeReferenceExprSyntax))"

    case .typedPointer(let step, swiftType: let type):
      let untypedExpr = step.asExprSyntax(isSelf: isSelf, placeholder: placeholder)
      return "\(untypedExpr).assumingMemoryBound(to: \(type.metatypeReferenceExprSyntax))"

    case .pointee(let step):
      let untypedExpr = step.asExprSyntax(isSelf: isSelf, placeholder: placeholder)
      return "\(untypedExpr).pointee"

    case .passIndirectly(let step):
      let innerExpr = step.asExprSyntax(isSelf: false, placeholder: placeholder)
      return isSelf ? innerExpr : "&\(innerExpr)"

    case .initialize(let type, arguments: let arguments):
      let renderedArguments: [String] = arguments.map { labeledArgument in
        let renderedArg = labeledArgument.argument.asExprSyntax(isSelf: false, placeholder: placeholder)
        if let argmentLabel = labeledArgument.label {
          return "\(argmentLabel): \(renderedArg.description)"
        } else {
          return renderedArg.description
        }
      }

      // FIXME: Should be able to use structured initializers here instead
      // of splatting out text.
      let renderedArgumentList = renderedArguments.joined(separator: ", ")
      return "\(raw: type.description)(\(raw: renderedArgumentList))"

    case .tuplify(let elements):
      let renderedElements: [String] = elements.enumerated().map { (index, element) in
        element.asExprSyntax(isSelf: false, placeholder: "\(placeholder)_\(index)").description
      }

      // FIXME: Should be able to use structured initializers here instead
      // of splatting out text.
      let renderedElementList = renderedElements.joined(separator: ", ")
      return "(\(raw: renderedElementList))"
    }
  }
}
