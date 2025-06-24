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

import Foundation

// Regex is not sendable yet so we can't cache it in a let
fileprivate var GradleDependencyDescriptorRegex: Regex<(Substring, Substring, Substring, Substring)> {
  try! Regex(#"^([^:]+):([^:]+):(\d[^:]+)$"#) // TODO: improve the regex to be more precise
}

// note: can't use `package` access level since it would break in usage in plugins in `_PluginsShared`.
public func parseDependencyDescriptor(_ descriptor: String) -> JavaDependencyDescriptor? {
  guard let match = try? GradleDependencyDescriptorRegex.firstMatch(in: descriptor) else {
    return nil
  }

  let groupID = String(match.1)
  let artifactID = String(match.2)
  let version = String(match.3)

  return JavaDependencyDescriptor(groupID: groupID, artifactID: artifactID, version: version)
}

// note: can't use `package` access level since it would break in usage in plugins in `_PluginsShared`.
public func parseDependencyDescriptors(_ string: String) -> [JavaDependencyDescriptor] {
  let descriptors = string.components(separatedBy: ",")
  var parsedDependencies: [JavaDependencyDescriptor] = []
  parsedDependencies.reserveCapacity(descriptors.count)

  for descriptor in descriptors {
    if let dependency = parseDependencyDescriptor(descriptor) {
      parsedDependencies.append(dependency)
    }
  }

  return parsedDependencies
}