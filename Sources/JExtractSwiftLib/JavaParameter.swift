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

/// Represent a parameter in Java code.
struct JavaParameter {
  let name: String
  let type: JavaType
  let annotations: [JavaAnnotation]

  init(name: String, type: JavaType, annotations: [JavaAnnotation] = []) {
    self.name = name
    self.type = type
    self.annotations = annotations
  }

  func renderParameter() -> String {
    if annotations.isEmpty {
      return "\(type) \(name)"
    }

    let annotationsStr = annotations.map({$0.render()}).joined(separator: "")
    return "\(annotationsStr) \(type) \(name)"
  }
}
