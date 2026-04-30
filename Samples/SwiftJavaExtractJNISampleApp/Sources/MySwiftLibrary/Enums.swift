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

public enum EnumWithValueCases {
  case firstCase(UInt)
  case secondCase
}

public enum EnumWithBacktick {
  case `let`
  case `default`
}

public enum EnumWithCaseNameValue {
  case success(Success)
  public struct Success {
    public init(message: String) {
      self.message = message
    }
    public var message: String
  }
}

public enum ComplexAssociatedValues {
  case generic(MyID<Int>, GenericEnum<Int>)
  case typealiasedGeneric(id: MyIntID)
  case array([String])
}
