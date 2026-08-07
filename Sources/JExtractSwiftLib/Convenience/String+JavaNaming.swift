//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024-2026 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftExtract

extension String {
  /// Returns whether the string is of the format `isX` (Java Beans boolean
  /// property naming convention)
  package var hasJavaBooleanNamingConvention: Bool {
    guard self.hasPrefix("is"), self.count > 2 else {
      return false
    }

    let thirdCharacterIndex = self.index(self.startIndex, offsetBy: 2)
    return self[thirdCharacterIndex].isUppercase
  }

  /// Joins components into a flat name, example: `JavaOuter_Inner_run_cb`
  package static func flatName(
    prefix: String? = nil,
    parent: SwiftQualifiedTypeName,
    method: String,
    parameter: String,
  ) -> String {
    "\(prefix ?? "")\(parent.fullFlatName)_\(method)_\(parameter)"
  }

  /// Joins components with `.`, example: `Outer.Inner.run.cb`
  package static func javaQualifiedName(_ components: String...) -> String {
    components.joined(separator: ".")
  }

  /// Java binary name for a nested synthetic type, example: `com.example.Outer$Inner$run$cb`
  ///
  /// - SeeAlso: [JLS 13.1 - The Form of a Binary](https://docs.oracle.com/javase/specs/jls/se21/html/jls-13.html#jls-13.1)
  package static func javaBinaryName(
    package javaPackage: String,
    parent: SwiftQualifiedTypeName,
    method: String,
    qualifier: String? = nil,
  ) -> String {
    let packagePrefix = javaPackage.isEmpty ? "" : "\(javaPackage)."
    let qualifierSuffix = qualifier.map { "$\($0)" } ?? ""
    return "\(packagePrefix)\(parent.jniEscapedName)$\(method)\(qualifierSuffix)"
  }

  /// JNI C symbol name for a `@_cdecl` native method entry point, example:
  /// `Java_com_example_Outer_00024Inner_run__I` (`Java_<package>_<Class>_<method>__<sig>`).
  /// - SeeAlso: https://docs.oracle.com/javase/8/docs/technotes/guides/jni/spec/design.html#resolving_native_method_names
  package static func jniSymbolName(
    package javaPackage: String,
    parent: SwiftQualifiedTypeName,
    method: String,
    signature: String,
  ) -> String {
    "Java_"
      + javaPackage.replacingOccurrences(of: ".", with: "_")
      + "_\(parent.jniEscapedName.escapedJNIIdentifier)_"
      + method.escapedJNIIdentifier
      + "__"
      + signature.escapedJNIIdentifier
  }
}
