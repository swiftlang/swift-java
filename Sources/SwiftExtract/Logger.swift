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
@_exported import SwiftExtractConfigurationShared
import SwiftSyntax

// Placeholder for some better logger, we could depend on swift-log
public struct Logger {
  public var label: String
  public var logLevel: LogLevel

  public init(label: String, logLevel: LogLevel) {
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
