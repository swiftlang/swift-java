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

/// Log verbosity levels for the analysis layer's lightweight logger.
///
/// Lives in the small `SwiftExtractConfigurationShared` target so the
/// analysis layer (`SwiftExtract`) and language-specific configuration
/// layers (e.g. swift-java's `SwiftJavaConfigurationShared`) can both
/// depend on it without dragging SwiftSyntax into the latter — same
/// shape as `AccessLevelMode`.
public enum LogLevel: String, ExpressibleByStringLiteral, Codable, Hashable, Sendable {
  case trace
  case debug
  case info
  case notice
  case warning
  case error
  case critical

  public init(stringLiteral value: String) {
    self = LogLevel(rawValue: value) ?? .info
  }
}

extension LogLevel {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)
    switch string {
    case "trace": self = .trace
    case "debug": self = .debug
    case "info": self = .info
    case "notice": self = .notice
    case "warning": self = .warning
    case "error": self = .error
    case "critical": self = .critical
    default: fatalError("Unknown value for \(LogLevel.self): \(string)")
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    let text =
      switch self {
      case .trace: "trace"
      case .debug: "debug"
      case .info: "info"
      case .notice: "notice"
      case .warning: "warning"
      case .error: "error"
      case .critical: "critical"
      }
    try container.encode(text)
  }
}

extension LogLevel: Comparable {
  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    lhs.naturalIntegralValue < rhs.naturalIntegralValue
  }

  var naturalIntegralValue: Int {
    switch self {
    case .trace: return 0
    case .debug: return 1
    case .info: return 2
    case .notice: return 3
    case .warning: return 4
    case .error: return 5
    case .critical: return 6
    }
  }
}
