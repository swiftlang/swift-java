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

// ==== -----------------------------------------------------------------------
// MARK: CodePrinterLanguage

/// Phantom-type tag identifying the language a `CodePrinter` emits.
/// Generators pick a concrete language so language-specific helpers
/// (e.g. `printGuardBlock` for Swift, `printIfBlock` shaped for Java)
/// resolve at compile time via constrained extensions.
public protocol CodePrinterLanguage: Sendable {
  /// Default lead used for inline comments (source-location trailers,
  /// `printSeparator` banners). May be overridden at the printer instance
  /// via `CodePrinter.inlineCommentStyle`.
  static var defaultInlineCommentStyle: InlineCommentStyle { get }
}

// ==== -----------------------------------------------------------------------
// MARK: Concrete languages

/// Swift output. `printIfBlock` writes `if <cond> { … }` (no parens around
/// the condition), and `printGuardBlock` is available.
public enum SwiftLanguage: CodePrinterLanguage {
  public static let defaultInlineCommentStyle: InlineCommentStyle = .slashSlash
}

/// Java output. `printIfBlock` writes `if (<cond>) { … }` (C-style parens).
public enum JavaLanguage: CodePrinterLanguage {
  public static let defaultInlineCommentStyle: InlineCommentStyle = .slashSlash
}

// ==== -----------------------------------------------------------------------
// MARK: Typealiases

/// Convenience for `CodePrinter<SwiftLanguage>`. Use this everywhere a
/// printer's output is Swift code.
public typealias SwiftPrinter = CodePrinter<SwiftLanguage>

/// Convenience for `CodePrinter<JavaLanguage>`. Use this everywhere a
/// printer's output is Java code.
public typealias JavaPrinter = CodePrinter<JavaLanguage>
