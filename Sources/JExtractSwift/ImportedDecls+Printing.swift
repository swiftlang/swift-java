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
import JavaTypes
import SwiftSyntax
import OrderedCollections

extension ImportedFunc {
  /// Render a `@{@snippet ... }` comment section that can be put inside a JavaDoc comment
  /// when referring to the original declaration a printed method refers to.
  var renderCommentSnippet: String? {
    if let syntax {
      """
      * {@snippet lang=swift :
      * \(syntax)
      * }
      """
    } else {
      nil
    }
  }
}

extension VariableAccessorKind {

  public var fieldSuffix: String {
    switch self {
      case .get: "_GET"
      case .set: "_SET"
    }
  }

  public var renderDescFieldName: String {
    switch self {
    case .get: "DESC_GET"
    case .set: "DESC_SET"
    }
  }

  public var renderAddrFieldName: String {
    switch self {
    case .get: "ADDR_GET"
    case .set: "ADDR_SET"
    }
  }

  public var renderHandleFieldName: String {
    switch self {
    case .get: "HANDLE_GET"
    case .set: "HANDLE_SET"
    }
  }

  /// Renders a "$get" part that can be used in a method signature representing this accessor.
  public var renderMethodNameSegment: String {
    switch self {
    case .get: "$get"
    case .set: "$set"
    }
  }

  func renderMethodName(_ decl: ImportedFunc) -> String? {
    switch self {
    case .get: "get\(decl.identifier.toCamelCase)"
    case .set: "set\(decl.identifier.toCamelCase)"
    }
  }
}

extension Optional where Wrapped == VariableAccessorKind {
  public var renderDescFieldName: String {
    self?.renderDescFieldName ?? "DESC"
  }

  public var renderAddrFieldName: String {
    self?.renderAddrFieldName ?? "ADDR"
  }

  public var renderHandleFieldName: String {
    self?.renderHandleFieldName ?? "HANDLE"
  }

  public var renderMethodNameSegment: String {
    self?.renderMethodNameSegment ?? ""
  }

  func renderMethodName(_ decl: ImportedFunc) -> String {
    self?.renderMethodName(decl) ?? decl.baseIdentifier
  }
}