//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import SwiftExtract

enum JNICaching {
  static func cacheName(for type: ImportedNominalType) -> String {
    cacheName(for: type.effectiveJavaTypeName)
  }

  static func cacheName(for type: SwiftNominalType) -> String {
    cacheName(for: type.nominalTypeDecl.qualifiedTypeName)
  }

  static func bridgeName(for type: ImportedNominalType) -> String {
    bridgeName(for: type.swiftNominal.qualifiedTypeName)
  }

  static func bridgeName(for type: SwiftNominalType) -> String {
    bridgeName(for: type.nominalTypeDecl.qualifiedTypeName)
  }

  private static func cacheName(for typeName: SwiftQualifiedTypeName) -> String {
    "_JNI_\(typeName.fullFlatName)"
  }

  private static func bridgeName(for typeName: SwiftQualifiedTypeName) -> String {
    "_JNIBridge_\(typeName.fullFlatName)"
  }

  static func cacheMemberName(for enumCase: ImportedEnumCase) -> String {
    "\(enumCase.enumType.nominalTypeDecl.name.firstCharacterLowercased)\(enumCase.name.firstCharacterUppercased)Cache"
  }

  static func cacheMemberName(for translatedEnumCase: JNISwift2JavaGenerator.TranslatedEnumCase) -> String {
    cacheMemberName(for: translatedEnumCase.original)
  }
}
