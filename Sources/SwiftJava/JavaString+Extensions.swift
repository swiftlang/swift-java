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

import CSwiftJavaJNI
import JavaTypes

extension JavaString: CustomStringConvertible, CustomDebugStringConvertible { 
  public var description: String {
    return toString()
  }
  public var debugDescription: String {
    return "\"" + toString() + "\""
  }
}

extension Optional where Wrapped == JavaString {
  public var description: String {
    switch self { 
      case .some(let value): "Optional(\(value.toString())"
      case .none: "nil"
    }
  }
}