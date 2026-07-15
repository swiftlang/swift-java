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

  static let all: [KnownJavaFunctionalInterface] = [
    .runnable
  ]

  static func find(parameters: [JavaType], result: JavaType) -> KnownJavaFunctionalInterface? {
    all.first { $0.parameters == parameters && $0.result == result }
  }

  static func find(parameters: [CType], result: CType) -> KnownJavaFunctionalInterface? {
    find(parameters: parameters.map(\.javaType), result: result.javaType)
  }

  static func find(_ methodSignature: MethodSignature) -> KnownJavaFunctionalInterface? {
    find(parameters: methodSignature.parameterTypes, result: methodSignature.resultType)
  }

  init(_ javaType: JavaType, method: String, parameters: [JavaType], result: JavaType) {
    self.javaType = javaType
    self.method = method
    self.parameters = parameters
    self.result = result
  }

}
