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

import SwiftJNI

/// Represent a parameter in Java code.
public struct JavaParameter {
  enum ParameterType: CustomStringConvertible {
    case concrete(JavaType)
    case generic(name: String, extends: [JavaType])

    public var jniTypeSignature: String {
      switch self {
      case .concrete(let type):
        return type.jniTypeSignature
      case .generic(_, let extends):
        guard !extends.isEmpty else {
          return "Ljava/lang/Object;"
        }

        // Generics only use the first type for JNI
        return extends.first!.jniTypeSignature
      }
    }

    public var jniTypeName: String {
      switch self {
      case .concrete(let type): type.jniTypeName
      case .generic: "jobject?"
      }
    }

    public var description: String {
      switch self {
      case .concrete(let type): type.description
      case .generic(let name, _): name
      }
    }
  }
  public var name: String
  var type: ParameterType

  /// Parameter annotations are used in parameter declarations like this: `@Annotation int example`
  public let annotations: [JavaAnnotation]

  init(name: String, type: ParameterType, annotations: [JavaAnnotation] = []) {
    self.name = name
    self.type = type
    self.annotations = annotations
  }

  init(name: String, type: JavaType, annotations: [JavaAnnotation] = []) {
    self.name = name
    self.type = .concrete(type)
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
