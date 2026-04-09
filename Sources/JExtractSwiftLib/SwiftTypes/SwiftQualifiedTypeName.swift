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

/// A structured representation of a Swift qualified type name such as
/// `Logger.Message`, providing self-documenting conversions to the various
/// string forms needed across the codebase:
/// - **qualifiedName** (`Logger.Message`) - for Swift source
/// - **flatName** (`Logger_Message`) - for C symbols / `@_cdecl` and Java identifiers
/// - **leafName** (`Message`) - innermost component only
package struct SwiftQualifiedTypeName: Hashable, Sendable, CustomStringConvertible {
  /// Name components from outermost to innermost, e.g. ["Logger", "Message"]
  let components: [String]

  init(_ components: [String]) {
    precondition(!components.isEmpty)
    self.components = components
  }

  init(_ leafName: String) {
    self.components = [leafName]
  }

  /// Leaf name (innermost), e.g. "Message"
  var leafName: String { components.last! }

  /// Dot-separated for Swift source, e.g. "Logger.Message"
  var fullName: String { components.joined(separator: ".") }

  /// Underscore-separated for C symbols and Java identifiers, e.g. "Logger_Message"
  var fullFlatName: String { components.joined(separator: "_") }

  /// Dollar-separated for JNI C symbol parent names, e.g. "Logger$Message"
  var jniEscapedName: String { components.joined(separator: "$") }

  /// CustomStringConvertible - uses fullName
  package var description: String { fullName }

  var isNested: Bool { components.count > 1 }
}
