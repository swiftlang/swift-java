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

/// Describes a Java annotation (e.g. `@Deprecated` or `@Unsigned`)
public struct JavaAnnotation: Equatable, Hashable {
  public let type: JavaType
  public let arguments: [String]

  public init(className name: some StringProtocol, arguments: [String] = []) {
    type = JavaType(className: name)
    self.arguments = arguments
  }

  public func render() -> String {
    guard let className = type.className else {
      fatalError("Java annotation must have a className")
    }

    var res = "@\(className)"
    guard !arguments.isEmpty else {
      return res
    }

    res += "("
    res += arguments.joined(separator: ",")
    res += ")"
    return res
  }

}

extension JavaAnnotation {
  public static var unsigned: JavaAnnotation {
    JavaAnnotation(className: "Unsigned")
  }
}
