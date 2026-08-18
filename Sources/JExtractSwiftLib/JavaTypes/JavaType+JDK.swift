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

import SwiftJavaJNICore

extension JavaType {
  /// The description of the type java.lang.foreign.MemorySegment.
  static var javaForeignMemorySegment: JavaType {
    .class(package: "java.lang.foreign", name: "MemorySegment")
  }

  /// The description of the type java.lang.String.
  static var javaLangString: JavaType {
    .class(package: "java.lang", name: "String")
  }

  /// The description of the type java.lang.Runnable.
  static var javaLangRunnable: JavaType {
    .class(package: "java.lang", name: "Runnable")
  }

  /// The description of the type java.util.function.BooleanSupplier.
  static var javaUtilFunctionBooleanSupplier: JavaType {
    .class(package: "java.util.function", name: "BooleanSupplier")
  }

  /// The description of the type java.util.function.IntSupplier.
  static var javaUtilFunctionIntSupplier: JavaType {
    .class(package: "java.util.function", name: "IntSupplier")
  }

  /// The description of the type java.util.function.LongSupplier.
  static var javaUtilFunctionLongSupplier: JavaType {
    .class(package: "java.util.function", name: "LongSupplier")
  }

  /// The description of the type java.util.function.DoubleSupplier.
  static var javaUtilFunctionDoubleSupplier: JavaType {
    .class(package: "java.util.function", name: "DoubleSupplier")
  }

  /// The description of the type java.util.function.IntConsumer.
  static var javaUtilFunctionIntConsumer: JavaType {
    .class(package: "java.util.function", name: "IntConsumer")
  }

  /// The description of the type java.util.function.LongConsumer.
  static var javaUtilFunctionLongConsumer: JavaType {
    .class(package: "java.util.function", name: "LongConsumer")
  }

  /// The description of the type java.util.function.DoubleConsumer.
  static var javaUtilFunctionDoubleConsumer: JavaType {
    .class(package: "java.util.function", name: "DoubleConsumer")
  }

  /// The description of the type java.util.function.IntPredicate.
  static var javaUtilFunctionIntPredicate: JavaType {
    .class(package: "java.util.function", name: "IntPredicate")
  }

  /// The description of the type java.util.function.LongPredicate.
  static var javaUtilFunctionLongPredicate: JavaType {
    .class(package: "java.util.function", name: "LongPredicate")
  }

  /// The description of the type java.util.function.DoublePredicate.
  static var javaUtilFunctionDoublePredicate: JavaType {
    .class(package: "java.util.function", name: "DoublePredicate")
  }

  /// The description of the type java.util.function.IntUnaryOperator.
  static var javaUtilFunctionIntUnaryOperator: JavaType {
    .class(package: "java.util.function", name: "IntUnaryOperator")
  }

  /// The description of the type java.util.function.LongUnaryOperator.
  static var javaUtilFunctionLongUnaryOperator: JavaType {
    .class(package: "java.util.function", name: "LongUnaryOperator")
  }

  /// The description of the type java.util.function.IntBinaryOperator.
  static var javaUtilFunctionIntBinaryOperator: JavaType {
    .class(package: "java.util.function", name: "IntBinaryOperator")
  }

  /// The description of the type java.util.function.LongBinaryOperator.
  static var javaUtilFunctionLongBinaryOperator: JavaType {
    .class(package: "java.util.function", name: "LongBinaryOperator")
  }

  /// The description of the type java.util.function.DoubleBinaryOperator.
  static var javaUtilFunctionDoubleBinaryOperator: JavaType {
    .class(package: "java.util.function", name: "DoubleBinaryOperator")
  }

  /// The description of the type java.lang.Class.
  static var javaLangClass: JavaType {
    .class(package: "java.lang", name: "Class")
  }

  /// The description of the type java.lang.Throwable.
  static var javaLangThrowable: JavaType {
    .class(package: "java.lang", name: "Throwable")
  }

  /// The description of the type java.lang.Object.
  static var javaLangObject: JavaType {
    .class(package: "java.lang", name: "Object")
  }

  /// The description of the type java.util.Optional.
  static func optional(_ T: JavaType) -> JavaType {
    .class(package: "java.util", name: "Optional", typeParameters: [T])
  }

  /// The description of the type java.util.concurrent.CompletableFuture<T>
  static func completableFuture(_ T: JavaType) -> JavaType {
    .class(package: "java.util.concurrent", name: "CompletableFuture", typeParameters: [T.boxedType])
  }

  /// The description of the type java.util.concurrent.Future<T>
  static func future(_ T: JavaType) -> JavaType {
    .class(package: "java.util.concurrent", name: "Future", typeParameters: [T.boxedType])
  }

  static var javaUtilUUID: JavaType {
    .class(package: "java.util", name: "UUID")
  }

}
