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

/// Java class-level modifiers surfaced as an option set for the ``JavaClass``,
/// ``JavaRecord``, and ``JavaInterface`` attached macros.
///
/// ```swift
/// @JavaClass(.sealed, "com.example.Shape")
/// @JavaClass(.final,  "com.example.Leaf")
/// ```
///
/// Java sealed types don't carry an explicit permitted-subclass list in Swift:
/// the generator models the hierarchy directly in the type system. Sealed
/// interfaces become Swift enums with one case per permitted subclass; sealed
/// classes remain Swift classes and the permitted subclasses are just the
/// declared subclasses reachable via the enclosing type.
public struct JavaClassModifier: OptionSet, Sendable, Hashable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  /// Java `sealed` type. Has a specific set of subclasses in Java.
  public static let sealed = JavaClassModifier(rawValue: 1 << 0)

  /// Java `final` type. Cannot be extended in Java.
  public static let `final` = JavaClassModifier(rawValue: 1 << 1)

  /// Java `abstract` type. Cannot be instantiated directly.
  public static let abstract = JavaClassModifier(rawValue: 1 << 2)
}
