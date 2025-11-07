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

enum JNICaching {
  static func cacheName(for type: ImportedNominalType) -> String {
    cacheName(for: type.swiftNominal.qualifiedName)
  }

  static func cacheName(for type: SwiftNominalType) -> String {
    cacheName(for: type.nominalTypeDecl.qualifiedName)
  }

  private static func cacheName(for qualifiedName: String) -> String {
    "_JNI_\(qualifiedName.replacingOccurrences(of: ".", with: "_"))"
  }

  static func cacheMemberName(for enumCase: ImportedEnumCase) -> String {
    "\(enumCase.enumType.nominalTypeDecl.name.firstCharacterLowercased)\(enumCase.name.firstCharacterUppercased)Cache"
  }
}
