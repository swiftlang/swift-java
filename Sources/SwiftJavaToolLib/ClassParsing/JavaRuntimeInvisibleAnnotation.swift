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

/// A parsed annotation from a .class file's RuntimeInvisibleAnnotations attribute.
struct JavaRuntimeInvisibleAnnotation {
  /// Field descriptor of the annotation type,
  /// e.g. "Landroidx/annotation/RequiresApi;"
  let typeDescriptor: String

  /// Element-value pairs: name -> value. Only integer values are captured.
  let elements: [String: Int32]

  /// The fully-qualified Java class name derived from `typeDescriptor`,
  /// e.g. "androidx.annotation.RequiresApi".
  var fullyQualifiedName: String {
    // Strip leading 'L' and trailing ';', then replace '/' with '.'
    var name = typeDescriptor
    if name.hasPrefix("L") { name = String(name.dropFirst()) }
    if name.hasSuffix(";") { name = String(name.dropLast()) }
    return name.replacing("/", with: ".")
  }
}
