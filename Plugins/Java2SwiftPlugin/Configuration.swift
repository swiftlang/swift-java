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
/// Note: there is a copy of this struct in the Java2Swift library. They
/// must be kept in sync.
struct Configuration: Codable {
  /// The Java class path that should be passed along to the Java2Swift tool.
  var classPath: String? = nil

  /// The Java classes that should be translated to Swift. The keys are
  /// canonical Java class names (e.g., java.util.Vector) and the values are
  /// the corresponding Swift names (e.g., JavaVector).
  var classes: [String: String] = [:]

  var dependencies: [JavaDependencyDescriptor] = []
}

struct JavaDependencyDescriptor: Codable {
  var groupID: String
  var artifactID: String
  var version: String

  init(from decoder: any Decoder) throws {
    var container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    let parts = string.split(separator: ":")
    guard parts.count == 3 else {
      throw JavaDependencyDescriptorError(message: "Illegal dependency, did not match: `groupID:artifactID:version")
    }
    self.groupID = String(parts[0])
    self.artifactID = String(parts[1])
    self.version = String(parts[2])
  }

  func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode("\(self.groupID):\(self.artifactID):\(self.version)")
  }

  struct JavaDependencyDescriptorError: Error {
    let message: String
  }
}