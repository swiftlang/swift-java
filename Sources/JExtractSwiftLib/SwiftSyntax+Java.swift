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
import SwiftSyntax

extension AttributeListSyntax.Element {
  /// Whether this node has `SwiftJava` wrapping attributes (types that wrap Java classes).
  /// These are skipped during jextract because they represent Java->Swift wrappers.
  /// Note: `@JavaExport` is NOT included here — it forces export of Swift types to Java.
  package var isSwiftJavaMacro: Bool {
    guard case let .attribute(attr) = self else {
      // FIXME: Handle #if.
      return false
    }
    guard let attrName = attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text else { return false }
    switch attrName {
    case "JavaClass", "JavaInterface", "JavaField", "JavaStaticField", "JavaMethod", "JavaStaticMethod",
      "JavaImplementation":
      return true
    default:
      return false
    }
  }

  /// Whether this is a `@JavaExport` attribute (used on typealiases for specialization,
  /// or on struct/class/enum to force-include them even when excluded by filters)
  package var isJavaExport: Bool {
    guard case let .attribute(attr) = self else { return false }
    guard let attrName = attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text else { return false }
    return attrName == "JavaExport"
  }
}

extension SwiftNominalType {
  /// True iff the underlying Swift declaration uses one of the Java-wrapper
  /// macros (`@JavaClass`, `@JavaInterface`, …) — meaning the type represents
  /// a Java class wrapped for Swift, not a Swift type to be re-exported
  public var isSwiftJavaWrapper: Bool {
    nominalTypeDecl.syntax.attributes.contains(where: \.isSwiftJavaMacro)
  }
}
