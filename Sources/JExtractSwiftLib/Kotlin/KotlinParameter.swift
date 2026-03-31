//
//  KotlinParameter.swift
//  swift-java
//
//  Created by Tanish Azad on 30/03/26.
//

import SwiftJavaJNICore

/// Represent a parameter in Java code.
struct KotlinParameter {
  enum ParameterType: CustomStringConvertible {
    case concrete(JavaType)
    case generic(name: String, extends: [JavaType])

    /// Returns the concrete JavaType, or `.class` for generics.
    var javaType: JavaType {
      switch self {
      case .concrete(let type): type
      case .generic: .class(package: "java.lang", name: "Object")
      }
    }

    var description: String {
      switch self {
      case .concrete(let type): type.description
      case .generic(let name, _): name
      }
    }
  }
  var name: String
  var type: ParameterType

  /// Parameter annotations are used in parameter declarations like this: `@Annotation int example`
  let annotations: [JavaAnnotation]

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
      return "\(name): \(type)"
    }

    let annotationsStr = annotations.map({ $0.render() }).joined(separator: "")
    return "\(annotationsStr) \(name): \(type)"
  }
}
