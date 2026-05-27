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

// ==== -----------------------------------------------------------------------
// MARK: Java-facing name aliases for ImportedNominalType

extension ImportedNominalType {
  package var effectiveJavaTypeName: SwiftQualifiedTypeName { effectiveOutputTypeName }
  package var effectiveJavaName: String { effectiveOutputName }
  package var effectiveJavaSimpleName: String { effectiveOutputSimpleName }
  package var javaGenericClause: String { outputGenericClause }
}

// ==== -----------------------------------------------------------------------
// MARK: Java-facing name aliases for ImportedFunc

extension ImportedFunc {
  /// The Java getter name for a Swift property/subscript getter, following
  /// Java Beans conventions: `get<Name>` for non-boolean, `is<Name>` for
  /// boolean (unless the property already starts with `is`, in which case
  /// the original name is preserved).
  ///
  /// Returns `nil` when the underlying declaration is not a getter — i.e. a
  /// regular function, initializer, enum case, or setter — since those don't
  /// have a Java getter name.
  package var javaGetterName: String? {
    switch apiKind {
    case .getter, .subscriptGetter: break
    case .setter, .subscriptSetter, .function, .initializer, .enumCase: return nil
    }

    let returnsBoolean = self.functionSignature.result.type.asNominalTypeDeclaration?.knownTypeKind == .bool

    if !returnsBoolean {
      return "get\(self.name.firstCharacterUppercased)"
    } else if !self.name.hasJavaBooleanNamingConvention {
      return "is\(self.name.firstCharacterUppercased)"
    } else {
      return self.name
    }
  }

  /// The Java setter name for a Swift property/subscript setter. If the
  /// property already starts with `is` (boolean naming), the `is` prefix is
  /// stripped so the setter becomes `set<Name>` per Java Beans spec.
  ///
  /// Returns `nil` when the underlying declaration is not a setter — i.e. a
  /// regular function, initializer, enum case, or getter — since those don't
  /// have a Java setter name.
  package var javaSetterName: String? {
    switch apiKind {
    case .setter, .subscriptSetter: break
    case .getter, .subscriptGetter, .function, .initializer, .enumCase: return nil
    }

    let isBooleanSetter = self.functionSignature.parameters.first?.type.asNominalTypeDeclaration?.knownTypeKind == .bool

    if isBooleanSetter && self.name.hasJavaBooleanNamingConvention {
      // Safe to force unwrap due to `hasJavaBooleanNamingConvention` check.
      let propertyName = self.name.split(separator: "is", maxSplits: 1).last!
      return "set\(propertyName)"
    } else {
      return "set\(self.name.firstCharacterUppercased)"
    }
  }
}
