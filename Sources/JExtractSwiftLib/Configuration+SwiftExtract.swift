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

/// `Configuration` already exposes every property the analysis layer needs
/// (`swiftModule`, `swiftFilterInclude`, `effectiveMinimumInputAccessLevelMode`,
/// `logLevel`, …) — `LogLevel` and `AccessLevelMode` are the same enums on
/// both sides, both pulled in from `SwiftExtractConfigurationShared`. The
/// protocol extension on `SwiftExtractConfiguration` defaults
/// `availableImportModules` and `permitsUnresolvedTypeReferences`, so this
/// conformance is empty.
extension Configuration: SwiftExtractConfiguration {}
