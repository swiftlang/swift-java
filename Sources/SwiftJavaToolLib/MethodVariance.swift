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
import SwiftJava
import JavaLangReflect

/// Captures the relationship between two methods by comparing their parameter
/// and result types.
enum MethodVariance {
  /// The methods are equivalent.
  case equivalent

  /// The methods are unrelated, e.g., some parameter types are different or
  /// the return types cannot be compared.
  case unrelated

  /// The second method is covariant with the first, meaning that its result
  /// type is a subclass of the result type of the first method.
  case covariantResult

  /// The second method is contravariant with the first, meaning that its result
  /// type is a superclass of the result type of the first method.
  ///
  /// This is the same as getting a covariant result when flipping the order
  /// of the methods.
  case contravariantResult

  init(_ first: Method, _ second: Method) {
    // If there are obvious differences, note that these are unrelated.
    if first.getName() != second.getName() ||
        first.isStatic != second.isStatic ||
        first.getParameterCount() != second.getParameterCount() {
      self = .unrelated
      return
    }

    // Check the parameter types.
    for (firstParamType, secondParamType) in zip(first.getParameterTypes(), second.getParameterTypes()) {
      guard let firstParamType, let secondParamType else { continue }

      // If the parameter types don't match, these methods are unrelated.
      guard firstParamType.equals(secondParamType.as(JavaObject.self)) else {
        self = .unrelated
        return
      }
    }

    // Check the result type.
    let firstResultType = first.getReturnType()!
    let secondResultType = second.getReturnType()!

    // If the result types are equivalent, the methods are equivalent.
    if firstResultType.equals(secondResultType.as(JavaObject.self)) {
      self = .equivalent
      return
    }

    // If first result type is a subclass of the second result type, it's
    // covariant.
    if firstResultType.isSubclass(of: secondResultType.as(JavaClass<JavaObject>.self)!) {
      self = .covariantResult
      return
    }

    // If second result type is a subclass of the first result type, it's
    // contravariant.
    if secondResultType.isSubclass(of: firstResultType.as(JavaClass<JavaObject>.self)!) {
      self = .contravariantResult
      return
    }

    // Treat the methods as unrelated, because we cannot compare their result
    // types.
    self = .unrelated
  }
}

extension JavaClass {
  /// Whether this Java class is a subclass of the other Java class.
  func isSubclass(of other: JavaClass<JavaObject>) -> Bool {
    var current = self.as(JavaClass<JavaObject>.self)
    while let currentClass = current {
      if currentClass.equals(other.as(JavaObject.self)) {
        return true
      }

      current = currentClass.getSuperclass()
    }

    return false
  }
}
