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

  /// The description of the type org.swift.swiftkit.core.SimpleCompletableFuture<T>
  static func simpleCompletableFuture(_ T: JavaType) -> JavaType {
    .class(package: "org.swift.swiftkit.core", name: "SimpleCompletableFuture", typeParameters: [T.boxedType])
  }

  /// The maximum supported tuple arity.
  static let maxTupleArity = 24

  /// The description of the type org.swift.swiftkit.core.tuple.TupleN<T0, T1, ...>
  static func tuple(elementTypes: [JavaType]) -> JavaType {
    let arity = elementTypes.count
    guard arity <= maxTupleArity else {
      fatalError("Tuple arity \(arity) exceeds maximum supported arity of \(maxTupleArity)")
    }
    let genericParams = elementTypes.map(\.boxedName).joined(separator: ", ")
    return .class(package: "org.swift.swiftkit.core.tuple", name: "Tuple\(arity)<\(genericParams)>")
  }

  /// The description of the type org.swift.swiftkit.core.collections.SwiftDictionaryMap<K, V>
  static func swiftDictionaryMap(_ K: JavaType, _ V: JavaType) -> JavaType {
    .class(package: "org.swift.swiftkit.core.collections", name: "SwiftDictionaryMap", typeParameters: [K.boxedType, V.boxedType])
  }

  /// The description of the type org.swift.swiftkit.core.collections.SwiftSet<E>
  static func swiftSet(_ E: JavaType) -> JavaType {
    .class(package: "org.swift.swiftkit.core.collections", name: "SwiftSet", typeParameters: [E.boxedType])
  }

  /// A container for receiving Swift generic instances.
  static var _OutSwiftGenericInstance: JavaType {
    .class(package: "org.swift.swiftkit.core", name: "_OutSwiftGenericInstance")
  }

  // ==== -------------------------------------------------------------------
  // MARK: Exception types

  /// The Java exception type for the Swift error wrapper
  static var swiftJavaErrorException: JavaType {
    .class(package: "org.swift.swiftkit.ffm.generated", name: "SwiftJavaErrorException")
  }

  /// The Java exception type for integer overflow checks
  static var swiftIntegerOverflowException: JavaType {
    .class(package: "org.swift.swiftkit.core", name: "SwiftIntegerOverflowException")
  }

  /// Extract the simple class name from a `.class` JavaType
  var simpleClassName: String {
    switch self {
    case .class(_, let name, _): name
    default: fatalError("simpleClassName is only available for .class types, was: \(self)")
    }
  }
}
