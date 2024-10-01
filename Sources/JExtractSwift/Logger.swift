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
      metadata.isEmpty ? "\(metadata)" : ""

    print("[trace][\(file):\(line)](\(function)) \(message()) \(metadataString)")
  }
}

extension Logger {
  public enum Level: Int, Hashable {
    case trace = 0
    case debug = 1
    case info = 2
    case notice = 3
    case warning = 4
    case error = 5
    case critical = 6
  }
}

extension Logger.Level {
  public init(from decoder: any Decoder) throws {
    var container = try decoder.unkeyedContainer()
    let string = try container.decode(String.self)
    switch string {
    case "trace": self = .trace
    case "debug": self = .debug
    case "info": self = .info
    case "notice": self = .notice
    case "warning": self = .warning
    case "error": self = .error
    case "critical": self = .critical
    default: fatalError("Unknown value for \(Logger.Level.self): \(string)")
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

extension Logger.Level {
  internal var naturalIntegralValue: Int {
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
    return lhs.naturalIntegralValue < rhs.naturalIntegralValue
  }
}
