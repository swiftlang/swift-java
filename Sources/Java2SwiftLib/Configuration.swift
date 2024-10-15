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

/// Configuration for the Java2Swift translation tool, provided on a per-target
/// basis.
///
/// Note: there is a copy of this struct in the Java2Swift plugin. They
/// must be kept in sync.
package struct Configuration: Codable {
  /// The Java class path that should be passed along to the Java2Swift tool.
  package var classPath: String? = nil

  /// The Java classes that should be translated to Swift. The keys are
  /// canonical Java class names (e.g., java.util.Vector) and the values are
  /// the corresponding Swift names (e.g., JavaVector).
  package var classes: [String: String] = [:]

  package init(classPath: String? = nil, classes: [String : String] = [:]) {
    self.classPath = classPath
    self.classes = classes
  }
}
