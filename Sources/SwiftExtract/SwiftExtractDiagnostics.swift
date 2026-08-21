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

import SwiftSyntax

/// A diagnostic reported by the analyzer.
public struct SwiftExtractDiagnostic {
  public enum Kind {
    /// The declaration was skipped entirely and is absent from the
    /// `AnalysisResult`.
    case skippedDeclaration
  }

  public let kind: Kind

  /// Qualified name of the affected declaration, formatted for human-readable
  /// output (e.g. `Greeter.greet(name:)`).
  public let declarationName: String

  /// Name of the module being analyzed.
  public let moduleName: String

  /// Neutral, consumer-independent description of what went wrong. Does not
  /// include `SwiftExtractConfiguration.unresolvedTypeHint`, which is only
  /// appended to the analyzer's own log output.
  public let message: String

  /// The syntax node the event is anchored to. Consumers can derive precise
  /// source locations from it: its root tree is the parsed source file.
  public let node: Syntax

  /// Path of the source file containing `node`, as supplied to the analyzer.
  public let sourceFilePath: String

  /// The error that caused the declaration to be diagnosed, when one was thrown.
  public let underlyingError: (any Error)?
}

/// Receives diagnostic events during analysis.
///
/// Supplying a sink does not suppress the analyzer's log output.
public protocol SwiftExtractDiagnosticsSink {
  func emit(_ diagnostic: SwiftExtractDiagnostic)
}
