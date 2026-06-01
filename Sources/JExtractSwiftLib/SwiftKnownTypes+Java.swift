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

extension SwiftNominalTypeDeclaration {
  /// True if this is swift-java's runtime `SwiftJavaError` type, which jextract
  /// maps to a thrown Java exception rather than an ordinary wrapped nominal
  package var isSwiftJavaErrorType: Bool {
    moduleName == "SwiftRuntimeFunctions" && name == "SwiftJavaError"
  }
}

extension SwiftKnownTypeDeclKind {
  /// Indicates whether this known type is translated by `wrap-java`
  /// into the same type as `jextract`.
  ///
  /// This means we do not have to perform any mapping when passing
  /// this type between jextract and wrap-java
  package var isDirectlyTranslatedToWrapJava: Bool {
    switch self {
    case .bool, .int, .uint, .int8, .uint8, .int16, .uint16, .int32, .uint32, .int64, .uint64, .float, .double, .string,
      .void:
      return true
    default:
      return false
    }
  }
}
