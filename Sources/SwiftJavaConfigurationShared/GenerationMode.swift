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

/// Determines which source generation mode JExtract should be using: JNI or Foreign Function and Memory.
public enum JExtractGenerationMode: String, Codable {
  /// Foreign Value and Memory API
  case ffm

  /// Java Native Interface
  case jni
}

/// Configures how Swift unsigned integers should be extracted by jextract.
public enum JExtractUnsignedIntegerMode: String, Codable {
  /// Treat unsigned Swift integers as their signed equivalents in Java signatures,
  /// however annotate them using the `@Unsigned` annotation which serves as a hint
  /// to users of APIs with unsigned integers that a given parameter or return type
  /// is actually unsigned, and must be treated carefully.
  ///
  /// Specifically negative values of a `@Unchecked long` must be interpreted carefully as
  /// a value larger than the Long.MAX_VALUE can represent in Java.
  case annotate

  /// Wrap any unsigned Swift integer values in an explicit `Unsigned...` wrapper types.
  ///
  /// This mode trades off performance, due to needing to allocate the type-safe wrapper objects around
  /// primitive values, however allows to retain static type information about the unsignedness of
  /// unsigned number types in the Java side of generated bindings.
  case wrapGuava

//  /// If possible, use a wider Java signed integer type to represent an Unsigned Swift integer type.
//  /// For example, represent a Swift `UInt32` (width equivalent to Java `int`) as a Java signed `long`,
//  /// because UInt32's max value is possible to be stored in a signed Java long (64bit).
//  ///
//  /// Since it is not possible to widen a value beyond 64bits (Java `long`), the Long type would be wrapped
//  case widenOrWrap
//
//  /// Similar to `widenOrWrap`, however instead of wrapping `UInt64` as an `UnsignedLong` in Java,
//  /// only annotate it as `@Unsigned long`.
//  case widenOrAnnotate
}

extension JExtractUnsignedIntegerMode {
  public var needsConversion: Bool {
    switch self {
    case .annotate: false
    case .wrapGuava: true
    }
  }

  public static var `default`: Self {
    .annotate
  }
}

/// The minimum access level which
public enum JExtractMinimumAccessLevelMode: String, Codable {
  case `public`
  case `package`
  case `internal`
}

extension JExtractMinimumAccessLevelMode {
  public static var `default`: Self {
    .public
  }
}


/// Configures how memory should be managed by the user
public enum JExtractMemoryManagementMode: String, Codable {
  /// Force users to provide an explicit `SwiftArena` to all calls that require them.
  case explicit

  /// Provide both explicit `SwiftArena` support
  /// and a default global automatic `SwiftArena` that will deallocate memory when the GC decides to.
  case allowGlobalAutomatic

  public static var `default`: Self {
    .explicit
  }

  public var requiresGlobalArena: Bool {
    switch self {
    case .explicit: false
    case .allowGlobalAutomatic: true
    }
  }
}
