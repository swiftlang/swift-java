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

import SwiftJavaJNICore

extension JavaType {

  /// The description of the type org.swift.swiftkit.core.collections.SwiftDictionaryMap<K, V>
  static func swiftDictionaryMap(_ K: JavaType, _ V: JavaType) -> JavaType {
    .class(package: "org.swift.swiftkit.core.collections", name: "SwiftDictionaryMap", typeParameters: [K.boxedType, V.boxedType])
  }

  /// The description of the type org.swift.swiftkit.core.collections.SwiftSet<E>
  static func swiftSet(_ E: JavaType) -> JavaType {
    .class(package: "org.swift.swiftkit.core.collections", name: "SwiftSet", typeParameters: [E.boxedType])
  }
}
