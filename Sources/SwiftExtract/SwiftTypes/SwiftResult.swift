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

public struct SwiftResult: Equatable {
  public var convention: SwiftResultConvention // currently not used.
  public var type: SwiftType

  public init(convention: SwiftResultConvention, type: SwiftType) {
    self.convention = convention
    self.type = type
  }
}

public enum SwiftResultConvention: Equatable {
  case direct
  case indirect
}

extension SwiftResult {
  public static var void: Self {
    Self(convention: .direct, type: .void)
  }
}
