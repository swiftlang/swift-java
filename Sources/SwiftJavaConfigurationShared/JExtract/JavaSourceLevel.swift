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

/// The Java source level to target when generating Java code.
///
/// Controls which Java language features may appear in generated output.
/// Encoded as a plain integer in JSON (e.g. `"javaSourceLevel": 17`).
public enum JavaSourceLevel: Int, Comparable, Sendable {
  case jdk17 = 17
  case jdk18 = 18
  case jdk21 = 21
  case jdk22 = 22
  case jdk24 = 24

  public static var `default`: Self { .jdk22 }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }
}

// ==== -----------------------------------------------------------------------
// MARK: Codable

extension JavaSourceLevel: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(Int.self)
    guard let level = JavaSourceLevel(rawValue: rawValue) else {
      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unknown JavaSourceLevel: \(rawValue). Supported values: \(JavaSourceLevel.allCases.map(\.rawValue))"
      )
    }
    self = level
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

extension JavaSourceLevel: CaseIterable {}
