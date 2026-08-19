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

import SwiftSyntax

extension ExtractedNominalType {
  public var attributeList: AttributeListSyntax {
    swiftNominal.syntax.attributes
  }

  public func attribute(named name: String) -> AttributeSyntax? {
    Self.first(attribute: name, in: attributeList)
  }

  static func first(attribute name: String, in attributes: AttributeListSyntax) -> AttributeSyntax? {
    for element in attributes {
      guard let attr = element.as(AttributeSyntax.self),
        let attrName = attr.attributeName.as(IdentifierTypeSyntax.self)?.name.text,
        attrName == name
      else {
        continue
      }
      return attr
    }
    return nil
  }
}

extension ExtractedFunc {
  public var attributeList: AttributeListSyntax? {
    if let n = swiftDecl.as(FunctionDeclSyntax.self) { return n.attributes }
    if let n = swiftDecl.as(InitializerDeclSyntax.self) { return n.attributes }
    if let n = swiftDecl.as(VariableDeclSyntax.self) { return n.attributes }
    if let n = swiftDecl.as(SubscriptDeclSyntax.self) { return n.attributes }
    if let n = swiftDecl.as(EnumCaseDeclSyntax.self) { return n.attributes }
    return nil
  }

  public func attribute(named name: String) -> AttributeSyntax? {
    guard let list = attributeList else { return nil }
    return ExtractedNominalType.first(attribute: name, in: list)
  }
}

extension ExtractedEnumCase {
  public var attributeList: AttributeListSyntax? {
    swiftDecl.as(EnumCaseDeclSyntax.self)?.attributes
  }

  public func attribute(named name: String) -> AttributeSyntax? {
    guard let list = attributeList else { return nil }
    return ExtractedNominalType.first(attribute: name, in: list)
  }
}
