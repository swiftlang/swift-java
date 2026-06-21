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

import SwiftJavaConfigurationShared

// ==== -----------------------------------------------------------------------
// MARK: CodePrinterLanguage

/// Phantom-type tag identifying the language a `CodePrinter` emits.
/// Generators pick a concrete language so language-specific helpers
/// (e.g. `printGuardBlock` for Swift, `printIfBlock` shaped for Java)
/// resolve at compile time via constrained extensions.
public protocol CodePrinterLanguage: Sendable {
  /// Per-language printer options. Defaults to `Void` for languages
  /// that don't need any (e.g. Swift today). Java carries the targeted
  /// source version so helpers can pick the right syntax shape.
  associatedtype Options: Sendable = Void

  /// Default lead used for inline comments (source-location trailers,
  /// `printSeparator` banners). May be overridden at the printer instance
  /// via `CodePrinter.inlineCommentStyle`.
  static var defaultInlineCommentStyle: InlineCommentStyle { get }

  /// Default value for `CodePrinter.options`.
  static var defaultOptions: Options { get }
}

extension CodePrinterLanguage where Options == Void {
  public static var defaultOptions: Void { () }
}

// ==== -----------------------------------------------------------------------
// MARK: Concrete languages

/// Swift output.
public enum SwiftLanguage: CodePrinterLanguage {
  public static let defaultInlineCommentStyle: InlineCommentStyle = .slashSlash
}

/// Java output.
public enum JavaLanguage: CodePrinterLanguage {
  public struct Options: Sendable {
    /// Targeted Java source version.
    public var sourceVersion: JavaVersion

    public init(sourceVersion: JavaVersion = 8) {
      self.sourceVersion = sourceVersion
    }
  }

  public static let defaultInlineCommentStyle: InlineCommentStyle = .slashSlash
  public static let defaultOptions = Options()
}

// ==== -----------------------------------------------------------------------
// MARK: Typealiases

/// Convenience for `CodePrinter<SwiftLanguage>`. Use this everywhere a
/// printer's output is Swift code.
public typealias SwiftPrinter = CodePrinter<SwiftLanguage>

/// Convenience for `CodePrinter<JavaLanguage>`. Use this everywhere a
/// printer's output is Java code.
public typealias JavaPrinter = CodePrinter<JavaLanguage>
