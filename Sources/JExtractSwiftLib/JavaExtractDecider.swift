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

import SwiftExtract
import SwiftSyntax

/// Java-specific extraction overrides applied on top of SwiftExtract's
/// built-in access-level filter:
///
/// - `@JavaExport` forces extraction even of non-public decls
/// - `@JavaClass` / `@JavaInterface` / `@JavaField` / `@JavaStaticField` /
///   `@JavaMethod` / `@JavaStaticMethod` / `@JavaImplementation` are Swift
///   wrappers of Java types — skip them during extraction
public struct JavaExtractDecider: ExtractDecider {
  public init() {}

  public func shouldExtract(decl: DeclSyntax, accessLevelPasses: Bool) -> Bool? {
    let attrs = decl.asProtocol(WithAttributesSyntax.self)?.attributes
    if attrs?.contains(where: { $0.isJavaExport }) == true {
      return true
    }
    if attrs?.contains(where: { $0.isSwiftJavaMacro }) == true {
      return false
    }
    return nil
  }
}
