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

import JavaLangReflect

/// Errors that can occur when translating Java types into Swift.
enum TranslationError: Error {
  /// The given Java class has not been translated into Swift.
  case untranslatedJavaClass(String)

  /// Unhandled Java type
  case unhandledJavaType(Type)
}

extension TranslationError: CustomStringConvertible {
  var description: String {
    switch self {
    case .untranslatedJavaClass(let name):
      return "Java class '\(name)' has not been translated into Swift"

    case .unhandledJavaType(let type):
      return "Unhandled Java type \(type.getTypeName())"
    }
  }
}
