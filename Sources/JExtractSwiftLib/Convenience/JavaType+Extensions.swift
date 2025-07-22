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
    case .boolean: return "Z"
    case .byte: return "B"
    case .char: return "C"
    case .short: return "S"
    case .int: return "I"
    case .long: return "J"
    case .float: return "F"
    case .double: return "D"
    case .class(let package, let name):
      let nameWithInnerClasses = name.replacingOccurrences(of: ".", with: "$")
      if let package {
        return "L\(package.replacingOccurrences(of: ".", with: "/"))/\(nameWithInnerClasses);"
      } else {
        return "L\(nameWithInnerClasses);"
      }
    case .array(let javaType): return  "[\(javaType.jniTypeSignature)"
    case .void: fatalError("There is no type signature for 'void'")
    }
  }
}
