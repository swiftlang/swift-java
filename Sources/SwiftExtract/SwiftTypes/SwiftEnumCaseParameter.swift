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

public struct SwiftEnumCaseParameter: Equatable {
  public var name: String?
  public var type: SwiftType
}

extension SwiftEnumCaseParameter {
  public init(
    _ node: EnumCaseParameterSyntax,
    lookupContext: SwiftTypeLookupContext
  ) throws {
    self.init(
      name: node.firstName?.identifier?.name,
      type: try SwiftType(node.type, lookupContext: lookupContext)
    )
  }
}
