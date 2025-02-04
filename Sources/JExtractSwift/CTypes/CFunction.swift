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

/// Describes a C function.
public struct CFunction {
  /// The result type of the function.
  public var resultType: CType

  /// The name of the function.
  public var name: String

  /// The parameters of the function.
  public var parameters: [CParameter]

  /// Whether the function is variadic.
  public var isVariadic: Bool

  public init(resultType: CType, name: String, parameters: [CParameter], isVariadic: Bool) {
    self.resultType = resultType
    self.name = name
    self.parameters = parameters
    self.isVariadic = isVariadic
  }

  /// Produces the type of the function.
  public var functionType: CType {
    .function(
      resultType: resultType,
      parameters: parameters.map { $0.type },
      variadic: isVariadic
    )
  }
}

extension CFunction: CustomStringConvertible {
  /// Print the declaration of this C function
  public var description: String {
    var result = ""

    var hasEmptyPlaceholder = false
    resultType.printBefore(hasEmptyPlaceholder: &hasEmptyPlaceholder, result: &result)

    result += name

    // Function parameters.
    result += "("
    result += parameters.map { $0.description }.joined(separator: ", ")
    CType.printFunctionParametersSuffix(
      isVariadic: isVariadic,
      hasZeroParameters: parameters.isEmpty,
      to: &result
    )
    result += ")"

    resultType.printAfter(
      hasEmptyPlaceholder: &hasEmptyPlaceholder,
      result: &result
    )

    result += ""
    return result
  }
}
