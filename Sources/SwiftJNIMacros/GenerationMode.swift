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
import SwiftSyntaxMacros

/// The mode of code generation being used for macros.
enum GenerationMode {
  /// This macro is describing a Java class in Swift.
  case importFromJava

  /// This macro is describing a Swift type that will be represented by
  /// a generated Java class.
  case exportToJava

  /// This macro is describing an extension that is implementing the native
  /// methods of a Java class.
  case javaImplementation

  /// Determine the mode for Java class generation based on an attribute.
  init?(attribute: AttributeSyntax) {
    switch attribute.attributeName.trimmedDescription {
    case "JavaClass", "JavaInterface":
      self = .importFromJava

    case "ExportToJavaClass":
      self = .exportToJava

    case "JavaImplementation":
      self = .javaImplementation

    default:
      return nil
    }
  }

  /// Determine the mode for Java class generation based on the the macro
  /// expansion context.
  init?(expansionContext: some MacroExpansionContext) {
    for lexicalContext in expansionContext.lexicalContext {
      // FIXME: swift-syntax probably needs an AttributedSyntax node for us
      // to look at. For now, we can look at just structs and extensions.
      let attributes: AttributeListSyntax
      if let structSyntax = lexicalContext.as(StructDeclSyntax.self) {
        attributes = structSyntax.attributes
      } else if let classSyntax = lexicalContext.as(ClassDeclSyntax.self) {
        attributes = classSyntax.attributes
      } else if let extSyntax = lexicalContext.as(ExtensionDeclSyntax.self) {
        attributes = extSyntax.attributes
      } else {
        continue
      }

      // Look for the first attribute that is associated with a mode, and
      // return that.
      for attribute in attributes {
        if case .attribute(let attribute) = attribute,
           let mode = GenerationMode(attribute: attribute) {
          self = mode
          return
        }
      }
    }

    return nil
  }
}
