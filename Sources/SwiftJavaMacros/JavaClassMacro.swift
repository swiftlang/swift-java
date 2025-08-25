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

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation // for e.g. replacingOccurrences

package enum JavaClassMacro {}

extension JavaClassMacro: MemberMacro {
  package static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let namedDecl = declaration.asProtocol(NamedDeclSyntax.self) else {
      throw MacroErrors.javaClassNotOnType
    }
    let swiftName = namedDecl.name.text

    // Dig out the Java class name.
    guard case .argumentList(let arguments) = node.arguments,
      let wrapperTypeNameExpr = arguments.first?.expression,
      let stringLiteral = wrapperTypeNameExpr.as(StringLiteralExprSyntax.self),
      stringLiteral.segments.count == 1,
      case let .stringSegment(classNameSegment)? = stringLiteral.segments.first
    else {
      throw MacroErrors.classNameNotStringLiteral
    }

    // Determine whether we're exposing the Java class as a Swift class, which
    // changes how we generate some of the members.
    let isSwiftClass: Bool
    let isJavaLangObject: Bool
    let specifiedSuperclass: String?
    if let classDecl = declaration.as(ClassDeclSyntax.self) {
      isSwiftClass = true
      isJavaLangObject = classDecl.isJavaLangObject

      // Retrieve the superclass, if there is one.
      specifiedSuperclass = classDecl.inheritanceClause?.inheritedTypes.first?.trimmedDescription
    } else {
      isSwiftClass = false
      isJavaLangObject = false

      // Dig out the "extends" argument from the attribute.
      if let superclassArg = arguments.dropFirst().first,
        let superclassArgLabel = superclassArg.label,
        superclassArgLabel.text == "extends",
        let superclassMemberAccess = superclassArg.expression.as(MemberAccessExprSyntax.self),
        superclassMemberAccess.declName.trimmedDescription == "self",
        let superclassMemberBase = superclassMemberAccess.base
      {
        specifiedSuperclass = superclassMemberBase.trimmedDescription
      } else {
        specifiedSuperclass = nil
      }
    }

    let superclass = specifiedSuperclass ?? "JavaObject"

    // Check that the class name is fully-qualified, as it should be.
    let className = classNameSegment.content.text
    if className.firstIndex(of: ".") == nil {
      throw MacroErrors.classNameNotFullyQualified(className)
    }

    var members: [DeclSyntax] = []

    // Determine the modifiers to use for the fullJavaClassName member.
    let fullJavaClassNameMemberModifiers: String
    switch (isSwiftClass, isJavaLangObject) {
    case (false, _):
      fullJavaClassNameMemberModifiers = "static"
    case (true, false):
      fullJavaClassNameMemberModifiers = "override class"
    case (true, true):
      fullJavaClassNameMemberModifiers = "class"
    }

    let classNameAccessSpecifier = isSwiftClass ? "open" : "public"
    members.append("""
      /// The full Java class name for this Swift type.
      \(raw: classNameAccessSpecifier) \(raw: fullJavaClassNameMemberModifiers) var fullJavaClassName: String { \(literal: className) }
      """
    )

    // struct wrappers need a JavaSuperclass type.
    if !isSwiftClass {
      members.append("""
        public typealias JavaSuperclass = \(raw: superclass)
        """
      )
    }

    // If this is for a struct or is the root java.lang.Object class, we need
    // a javaHolder instance property.
    if !isSwiftClass || isJavaLangObject {
      members.append("""
        public var javaHolder: JavaObjectHolder
        """
      )
    }

    let requiredModifierOpt = isSwiftClass ? "required " : ""
    let initBody: CodeBlockItemSyntax = isSwiftClass && !isJavaLangObject
      ? "super.init(javaHolder: javaHolder)"
      : "self.javaHolder = javaHolder"
    members.append("""
      public \(raw: requiredModifierOpt)init(javaHolder: JavaObjectHolder) {
          \(initBody)
      }
      """
    )

    if !isSwiftClass {
      members.append("""
        /// Casting to ``\(raw: superclass)`` will never be nil because ``\(raw: swiftName)`` extends it.
        public func `as`(_: \(raw: superclass).Type) -> \(raw: superclass) {
            return \(raw: superclass)(javaHolder: javaHolder)
        }
        """
      )
    }

    return members
  }
}

extension JavaClassMacro: ExtensionMacro {
  package static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo protocols: [TypeSyntax],
    in context: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    if protocols.isEmpty {
      return []
    }

    let AnyJavaObjectConformance: DeclSyntax =
      """
      extension \(type.trimmed): AnyJavaObject { }
      """

    return [AnyJavaObjectConformance.as(ExtensionDeclSyntax.self)!]
  }
}

extension ClassDeclSyntax {
  /// Whether this class describes java.lang.Object
  var isJavaLangObject: Bool {
    // FIXME: This is somewhat of a hack; we could look for
    // @JavaClass("java.lang.Object") instead.
    return name.text == "JavaObject"
  }
}
