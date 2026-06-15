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

import SwiftExtract

// ==== ----------------------------------------------------------------------
// MARK: Test analysis helpers

/// Drive `SwiftAnalyzer.analyze` from the test suite without spelling out an
/// `extractDecider:` argument every time. Builds a `DefaultExtractDecider`
/// from the supplied (or inferred) configuration's access-level setting,
/// matching the prior implicit-fallback behavior — these tests exercise the
/// language-neutral analysis layer, so the access-level-only baseline
/// decider is the right default.
func analyze(
  sources: [(path: String, text: String)],
  moduleName: String,
  config: (any SwiftExtractConfiguration)? = nil,
  sourceDependencies: SourceDependencies = SourceDependencies()
) throws -> AnalysisResult {
  let effectiveConfig = config ?? DefaultSwiftExtractConfiguration(swiftModule: moduleName)
  return try SwiftAnalyzer.analyze(
    sources: sources,
    moduleName: moduleName,
    config: effectiveConfig,
    sourceDependencies: sourceDependencies,
    extractDecider: DefaultExtractDecider(accessLevel: effectiveConfig.swiftExtractAccessLevel)
  )
}
