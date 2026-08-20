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
import SwiftJavaJNICore

/// Describes a known functional interface such as `Runnable.run()` and similar.
struct KnownJavaFunctionalInterface: Sendable {
  let javaType: JavaType
  let method: String
  let parameters: [JavaType]
  let result: JavaType

  static let runnable = KnownJavaFunctionalInterface(
    JavaType.javaLangRunnable,
    method: "run",
    parameters: [],
    result: .void
  )

  static let booleanSupplier = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionBooleanSupplier,
    method: "getAsBoolean",
    parameters: [],
    result: .boolean
  )

  static let intSupplier = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionIntSupplier,
    method: "getAsInt",
    parameters: [],
    result: .int
  )

  static let longSupplier = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionLongSupplier,
    method: "getAsLong",
    parameters: [],
    result: .long
  )

  static let doubleSupplier = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionDoubleSupplier,
    method: "getAsDouble",
    parameters: [],
    result: .double
  )

  static let intConsumer = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionIntConsumer,
    method: "accept",
    parameters: [.int],
    result: .void
  )

  static let longConsumer = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionLongConsumer,
    method: "accept",
    parameters: [.long],
    result: .void
  )

  static let doubleConsumer = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionDoubleConsumer,
    method: "accept",
    parameters: [.double],
    result: .void
  )

  static let intPredicate = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionIntPredicate,
    method: "test",
    parameters: [.int],
    result: .boolean
  )

  static let longPredicate = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionLongPredicate,
    method: "test",
    parameters: [.long],
    result: .boolean
  )

  static let doublePredicate = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionDoublePredicate,
    method: "test",
    parameters: [.double],
    result: .boolean
  )

  static let intUnaryOperator = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionIntUnaryOperator,
    method: "applyAsInt",
    parameters: [.int],
    result: .int
  )

  static let longUnaryOperator = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionLongUnaryOperator,
    method: "applyAsLong",
    parameters: [.long],
    result: .long
  )

  static let doubleUnaryOperator = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionDoubleUnaryOperator,
    method: "applyAsDouble",
    parameters: [.double],
    result: .double
  )

  static let intBinaryOperator = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionIntBinaryOperator,
    method: "applyAsInt",
    parameters: [.int, .int],
    result: .int
  )

  static let longBinaryOperator = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionLongBinaryOperator,
    method: "applyAsLong",
    parameters: [.long, .long],
    result: .long
  )

  static let doubleBinaryOperator = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionDoubleBinaryOperator,
    method: "applyAsDouble",
    parameters: [.double, .double],
    result: .double
  )

  static let doubleToIntFunction = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionDoubleToIntFunction,
    method: "applyAsInt",
    parameters: [.double],
    result: .int
  )

  static let longToIntFunction = KnownJavaFunctionalInterface(
    JavaType.javaUtilFunctionLongToIntFunction,
    method: "applyAsInt",
    parameters: [.long],
    result: .int
  )

  static let all: [KnownJavaFunctionalInterface] = [
    .runnable,
    .booleanSupplier,
    .intSupplier,
    .longSupplier,
    .doubleSupplier,
    .intConsumer,
    .longConsumer,
    .doubleConsumer,
    .intPredicate,
    .longPredicate,
    .doublePredicate,
    .intUnaryOperator,
    .longUnaryOperator,
    .doubleUnaryOperator,
    .intBinaryOperator,
    .longBinaryOperator,
    .doubleBinaryOperator,
    .doubleToIntFunction,
    .longToIntFunction,
  ]

  static func find(parameters: [JavaType], result: JavaType) -> KnownJavaFunctionalInterface? {
    all.first { $0.parameters == parameters && $0.result == result }
  }

  static func find(parameters: [CType], result: CType) -> KnownJavaFunctionalInterface? {
    find(parameters: parameters.map(\.javaType), result: result.javaType)
  }

  static func find(parameters: [JNISwift2JavaGenerator.TranslatedParameter], result: JNISwift2JavaGenerator.TranslatedResult) -> KnownJavaFunctionalInterface? {
    find(parameters: parameters.map(\.parameter.type.javaType), result: result.javaType)
  }

  static func find(_ methodSignature: MethodSignature) -> KnownJavaFunctionalInterface? {
    find(parameters: methodSignature.parameterTypes, result: methodSignature.resultType)
  }

  static func find(_ functionType: SwiftFunctionType) -> KnownJavaFunctionalInterface? {
    if functionType.isEscaping {
      return nil
    }

    let parameters = functionType.parameters
    let result = functionType.resultType

    // Runnable & Suppliers
    if parameters == [] {
      return switch () {
      case _ where result.isVoid:
        runnable
      case _ where result.isBoolean:
        booleanSupplier
      case _ where result.isInt32:
        intSupplier
      case _ where result.isInt64:
        longSupplier
      case _ where result.isDouble:
        doubleSupplier
      default:
        nil
      }
    }

    // Consumers
    if parameters.count == 1 && result.isVoid {
      let parameter = parameters[0].type
      return switch () {
      case _ where parameter.isInt32:
        intConsumer
      case _ where parameter.isInt64:
        longConsumer
      case _ where parameter.isDouble:
        doubleConsumer
      default:
        nil
      }
    }

    // Predicates
    if parameters.count == 1 && result.isBoolean {
      let parameter = parameters[0].type
      return switch () {
      case _ where parameter.isInt32:
        intPredicate
      case _ where parameter.isInt64:
        longPredicate
      case _ where parameter.isDouble:
        doublePredicate
      default:
        nil
      }
    }

    // Unary operators
    if parameters.count == 1 && parameters[0].type == result {
      let parameter = parameters[0].type
      return switch () {
      case _ where parameter.isInt32:
        intUnaryOperator
      case _ where parameter.isInt64:
        longUnaryOperator
      case _ where parameter.isDouble:
        doubleUnaryOperator
      default:
        nil
      }
    }

    // To int functions
    if parameters.count == 1 && result.isInt32 {
      let parameter = parameters[0].type
      return switch () {
      case _ where parameter.isInt64:
        longToIntFunction
      case _ where parameter.isDouble:
        doubleToIntFunction
      default:
        nil
      }
    }

    // Binary operators
    if parameters.count == 2 && parameters[0].type == result && parameters[1].type == result {
      let parameter = parameters[0].type
      return switch () {
      case _ where parameter.isInt32:
        intBinaryOperator
      case _ where parameter.isInt64:
        longBinaryOperator
      case _ where parameter.isDouble:
        doubleBinaryOperator
      default:
        nil
      }
    }

    return nil
  }

  static func find(_ functionType: JNISwift2JavaGenerator.TranslatedFunctionType) -> KnownJavaFunctionalInterface? {
    if functionType.isEscaping {
      return nil
    }
    return find(parameters: functionType.parameters, result: functionType.result)
  }

  static func find(_ functionType: FFMSwift2JavaGenerator.TranslatedFunctionType) -> KnownJavaFunctionalInterface? {
    if functionType.swiftType.isEscaping {
      return nil
    }
    return find(parameters: functionType.parameters.map(\.parameter.type.javaType), result: functionType.result.javaResultType)
  }

  init(_ javaType: JavaType, method: String, parameters: [JavaType], result: JavaType) {
    self.javaType = javaType
    self.method = method
    self.parameters = parameters
    self.result = result
  }

}
