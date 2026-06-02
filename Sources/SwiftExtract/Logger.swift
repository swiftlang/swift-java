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

import Foundation
import SwiftSyntax

// Placeholder for some better logger, we could depend on swift-log
public struct Logger {
  public var label: String
  public var logLevel: Logger.Level

  public init(label: String, logLevel: Logger.Level) {
    self.label = label
    self.logLevel = logLevel
  }

  public func error(
    _ message: @autoclosure () -> String,
    metadata: [String: Any] = [:],
    file: String = #fileID,
    line: UInt = #line,
    function: String = #function
  ) {
    guard logLevel <= .error else {
      return
    }

    let metadataString: String =
      if metadata.isEmpty { "" } else { "\(metadata)" }

    print("[error][\(file):\(line)](\(function)) \(message()) \(metadataString)")
  }

  public func warning(
    _ message: @autoclosure () -> String,
    metadata: [String: Any] = [:],
    file: String = #fileID,
    line: UInt = #line,
    function: String = #function
  ) {
    guard logLevel <= .warning else {
      return
    }

    let metadataString: String =
      if metadata.isEmpty { "" } else { "\(metadata)" }

    print("[warning][\(file):\(line)](\(function)) \(message()) \(metadataString)")
  }

  public func info(
    _ message: @autoclosure () -> String,
    metadata: [String: Any] = [:],
    file: String = #fileID,
    line: UInt = #line,
    function: String = #function
  ) {
    guard logLevel <= .info else {
      return
    }

    let metadataString: String =
      if metadata.isEmpty { "" } else { "\(metadata)" }

    print("[info][\(file):\(line)](\(function)) \(message()) \(metadataString)")
  }

  public func debug(
    _ message: @autoclosure () -> String,
    metadata: [String: Any] = [:],
    file: String = #fileID,
    line: UInt = #line,
    function: String = #function
  ) {
    guard logLevel <= .debug else {
      return
    }

    let metadataString: String =
      if metadata.isEmpty { "" } else { "\(metadata)" }

    print("[debug][\(file):\(line)](\(function)) \(message()) \(metadataString)")
  }

  public func trace(
    _ message: @autoclosure () -> String,
    metadata: [String: Any] = [:],
    file: String = #fileID,
    line: UInt = #line,
    function: String = #function
  ) {
    guard logLevel <= .trace else {
      return
    }

    let metadataString: String =
      metadata.isEmpty ? "" : "\(metadata)"

    print("[trace][\(file):\(line)](\(function)) \(message()) \(metadataString)")
  }
}

extension Logger {
  /// Log verbosity levels for the analysis layer's lightweight logger.
  ///
  /// Language-neutral; language-specific configuration modules map their own
  /// log-level enums onto this via `SwiftExtractConfiguration`.
  public enum Level: String, Codable, Hashable, Sendable {
    case trace
    case debug
    case info
    case notice
    case warning
    case error
    case critical
  }
}

extension Logger.Level {
  var naturalIntegralValue: Int {
    switch self {
    case .trace:
      return 0
    case .debug:
      return 1
    case .info:
      return 2
    case .notice:
      return 3
    case .warning:
      return 4
    case .error:
      return 5
    case .critical:
      return 6
    }
  }
}

extension Logger.Level: Comparable {
  public static func < (lhs: Logger.Level, rhs: Logger.Level) -> Bool {
    lhs.naturalIntegralValue < rhs.naturalIntegralValue
  }
}
