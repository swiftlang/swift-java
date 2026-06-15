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

import SwiftExtract
import SwiftJavaConfigurationShared

/// Bridges swift-java's `Configuration` onto the language-neutral
/// `SwiftExtractConfiguration` surface consumed by `SwiftExtract`.
///
/// Most members are satisfied directly by `Configuration`'s own properties.
/// `Configuration` shares `AccessLevelMode` with the analyzer (both pull it
/// in from `SwiftExtractConfigurationShared`), so
/// `effectiveMinimumInputAccessLevelMode` already conforms without a bridge.
/// Only `swiftExtractLogLevel` needs a mapping from swift-java's `LogLevel`
/// onto the neutral `Logger.Level`.
extension Configuration: SwiftExtractConfiguration {
  public var swiftExtractLogLevel: SwiftExtract.Logger.Level? {
    guard let logLevel else { return nil }
    switch logLevel {
    case .trace: return .trace
    case .debug: return .debug
    case .info: return .info
    case .notice: return .notice
    case .warning: return .warning
    case .error: return .error
    case .critical: return .critical
    }
  }
}

extension LogLevel {
  /// Bridges from the analysis layer's neutral `Logger.Level` (used by the CLI's
  /// `--log-level` option) onto swift-java's own `LogLevel`.
  public init(_ level: SwiftExtract.Logger.Level) {
    switch level {
    case .trace: self = .trace
    case .debug: self = .debug
    case .info: self = .info
    case .notice: self = .notice
    case .warning: self = .warning
    case .error: self = .error
    case .critical: self = .critical
    }
  }
}
