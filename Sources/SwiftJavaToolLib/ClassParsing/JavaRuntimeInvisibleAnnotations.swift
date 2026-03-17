//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import JavaLangReflect
import SwiftJava

/// Results of scanning a .class file for RuntimeInvisibleAnnotations.
struct JavaRuntimeInvisibleAnnotations {
  /// Annotations on the class itself.
  var classAnnotations: [JavaRuntimeInvisibleAnnotation] = []

  /// Annotations keyed by method descriptor, e.g. "api30Method()V"
  var methodAnnotations: [String: [JavaRuntimeInvisibleAnnotation]] = [:]

  /// Annotations keyed by field name, e.g. "OLD_VALUE"
  var fieldAnnotations: [String: [JavaRuntimeInvisibleAnnotation]] = [:]

  /// Returns annotations for a Java method, matched by name and exact descriptor.
  func annotationsFor(method javaMethod: Method) -> [JavaRuntimeInvisibleAnnotation] {
    let key = jvmMethodDescriptor(javaMethod)
    return methodAnnotations[key] ?? []
  }

  /// Returns annotations for a Java constructor, matched by exact descriptor.
  func annotationsFor(constructor: some Executable) -> [JavaRuntimeInvisibleAnnotation] {
    let key = jvmMethodDescriptor(constructor)
    return methodAnnotations[key] ?? []
  }

  /// Returns all annotations for a field with the given name.
  func annotationsFor(field name: String) -> [JavaRuntimeInvisibleAnnotation] {
    fieldAnnotations[name] ?? []
  }
}
