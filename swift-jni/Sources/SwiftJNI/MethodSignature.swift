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

/// Describes a Java method signature.
public struct MethodSignature: Equatable, Hashable {
  /// The result type of this method.
  public let resultType: JavaType

  /// The parameter types of this method.
  public let parameterTypes: [JavaType]

  public init(resultType: JavaType, parameterTypes: [JavaType]) {
    self.resultType = resultType
    self.parameterTypes = parameterTypes
  }
}
