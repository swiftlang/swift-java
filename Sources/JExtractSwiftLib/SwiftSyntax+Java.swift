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

/// Names of the JavaKit macros that wrap a Java class/interface/member from
/// Swift (Java -> Swift direction). A nominal carrying any of these is
/// skipped during jextract because the binding goes the other way.
///
/// `@JavaExport` is intentionally NOT here — it forces export of a Swift
/// type to Java (Swift -> Java direction) and uses a separate predicate.
let KnownJavaKitMacroNames: [String] = [
  "JavaClass",
  "JavaInterface",
  "JavaField",
  "JavaStaticField",
  "JavaMethod",
  "JavaStaticMethod",
  "JavaImplementation",
]

extension AttributeListSyntax.Element {
  /// Whether this node carries one of the JavaKit wrapping macros (types
  /// that wrap Java classes). These are skipped during jextract because they
  /// represent Java->Swift wrappers.
  /// Note: `@JavaExport` is NOT included here — it forces export of Swift
  /// types to Java.
  package var isJavaKitMacro: Bool {
    guard case let .attribute(attr) = self else {
      // FIXME: Handle #if.
      return false
    }
    guard let attrName = attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text else { return false }
    return KnownJavaKitMacroNames.contains(attrName)
  }

  /// Whether this is a `@JavaExport` attribute (used on typealiases for specialization,
  /// or on struct/class/enum to force-include them even when excluded by filters)
  package var isJavaExport: Bool {
    javaExportValue != nil
  }

  /// `true` for `@JavaExport`, `false` for `@JavaExport(false)`, `nil` for any other attribute
  package var javaExportValue: Bool? {
    guard case let .attribute(attr) = self else { return nil }
    guard attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text == "JavaExport" else { return nil }
    guard case .argumentList(let arguments) = attr.arguments,
      let literal = arguments.first?.expression.as(BooleanLiteralExprSyntax.self)
    else {
      return true
    }
    return literal.literal.tokenKind == .keyword(.true)
  }
}

extension SyntaxProtocol {
  /// The value of this declaration's own `@JavaExport` attribute, if it has one
  package var javaExportMarker: Bool? {
    guard let attributes = self.asProtocol((any WithAttributesSyntax).self)?.attributes else { return nil }
    return attributes.lazy.compactMap(\.javaExportValue).first
  }

  /// The `@JavaExport` value of the nearest enclosing type or extension that has one
  package var inheritedJavaExportMarker: Bool? {
    var node = self.parent
    while let current = node {
      if current.is(DeclSyntax.self), let marker = current.javaExportMarker {
        return marker
      }
      node = current.parent
    }
    return nil
  }

  /// Whether a member of this type, at any depth, is marked `@JavaExport`
  package var containsJavaExportedMember: Bool {
    guard let group = self.asProtocol((any DeclGroupSyntax).self) else { return false }
    return group.memberBlock.members.contains { item in
      item.decl.javaExportMarker == true || item.decl.containsJavaExportedMember
    }
  }
}

extension SwiftNominalType {
  /// True iff the underlying Swift declaration uses one of the Java-wrapper
  /// macros (`@JavaClass`, `@JavaInterface`, …) — meaning the type represents
  /// a Java class wrapped for Swift, not a Swift type to be re-exported
  public var isSwiftJavaWrapper: Bool {
    nominalTypeDecl.syntax.attributes.contains(where: \.isJavaKitMacro)
  }
}
