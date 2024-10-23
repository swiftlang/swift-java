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
    // Dig out the Java class name.
    guard case .argumentList(let arguments) = node.arguments,
      let wrapperTypeNameExpr = arguments.first?.expression,
      let stringLiteral = wrapperTypeNameExpr.as(StringLiteralExprSyntax.self),
      stringLiteral.segments.count == 1,
      case let .stringSegment(classNameSegment)? = stringLiteral.segments.first
    else {
      throw MacroErrors.classNameNotStringLiteral
    }

    // Dig out the "superclass" clause, if there is one.
    let superclass: String
    if let superclassArg = arguments.dropFirst().first,
      let superclassArgLabel = superclassArg.label,
      superclassArgLabel.text == "extends",
      let superclassMemberAccess = superclassArg.expression.as(MemberAccessExprSyntax.self),
      superclassMemberAccess.declName.trimmedDescription == "self",
      let superclassMemberBase = superclassMemberAccess.base
    {
      superclass = superclassMemberBase.trimmedDescription
    } else {
      superclass = "JavaObject"
    }

    // Check that the class name is fully-qualified, as it should be.
    let className = classNameSegment.content.text
    if className.firstIndex(of: ".") == nil {
      throw MacroErrors.classNameNotFullyQualified(className)
    }

    let fullJavaClassNameMember: DeclSyntax = """
      /// The full Java class name for this Swift type.
      public static var fullJavaClassName: String { \(literal: className) }
      """

    let superclassTypealias: DeclSyntax = """
      public typealias JavaSuperclass = \(raw: superclass)
      """

    let javaHolderMember: DeclSyntax = """
      public var javaHolder: JavaObjectHolder
      """

    let javaThisMember: DeclSyntax = """
      public var javaThis: jobject {
        javaHolder.object!
      }
      """

    let javaEnvironmentMember: DeclSyntax = """
      public var javaEnvironment: JNIEnvironment {
        javaHolder.environment
      }
      """

    let initMember: DeclSyntax = """
      public init(javaHolder: JavaObjectHolder) {
          self.javaHolder = javaHolder
      }
      """

    let nonOptionalAs: DeclSyntax = """
      /// Casting to ``\(raw: superclass)`` will never be nil because ``\(raw: className.split(separator: ".").last!)`` extends it.
      public func `as`(_: \(raw: superclass).Type) -> \(raw: superclass) {
          return \(raw: superclass)(javaHolder: javaHolder)
      }
      """

    return [
      fullJavaClassNameMember,
      superclassTypealias,
      javaHolderMember,
      javaThisMember,
      javaEnvironmentMember,
      initMember,
      nonOptionalAs,
    ]
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
