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

import JavaTypes

extension JavaType {
  var jniTypeSignature: String {
    switch self {
    case .boolean: "Z"
    case .byte: "B"
    case .char: "C"
    case .short: "S"
    case .int: "I"
    case .long: "J"
    case .float: "F"
    case .double: "D"
    case .class(let package, let name):
      if let package {
        "L\(package.replacingOccurrences(of: ".", with: "/"))/\(name);"
      } else {
        "L\(name);"
      }
    case .array(let javaType): "[\(javaType.jniTypeSignature)"
    case .void: fatalError("There is no type signature for 'void'")
    }
  }
}
