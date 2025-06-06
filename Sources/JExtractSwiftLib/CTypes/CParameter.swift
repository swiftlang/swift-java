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

/// Describes a parameter to a C function.
public struct CParameter {
  /// The name of the parameter, if provided.
  public var name: String?

  /// The type of the parameter.
  public var type: CType

  public init(name: String? = nil, type: CType) {
    self.name = name
    self.type = type
  }
}

extension CParameter: CustomStringConvertible {
  public var description: String {
    type.print(placeholder: name ?? "")
  }
}
