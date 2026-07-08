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

import Foundation

/// Splices generated content into a Markdown file between START/END markers.
struct MarkerSplicer {
  static let startMarker = "<!-- SWIFT_JAVA_CONFIG_DOCS:START -->"
  static let endMarker = "<!-- SWIFT_JAVA_CONFIG_DOCS:END -->"

  static func splice(into doc: String, generated: String) throws -> String {
    guard let startRange = doc.range(of: startMarker) else {
      throw ConfigDocsError("Could not find '\(startMarker)' marker in doc file")
    }
    guard let endRange = doc.range(of: endMarker),
      endRange.lowerBound > startRange.upperBound
    else {
      throw ConfigDocsError("Could not find '\(endMarker)' marker (after start) in doc file")
    }
    let before = doc[..<startRange.lowerBound]
    let after = doc[endRange.upperBound...]
    return "\(before)\(startMarker)\n\n\(generated)\n\(endMarker)\(after)"
  }
}
