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

import ArgumentParser
import SwiftExtract
import SwiftJavaConfigurationShared

extension Logger.Level: ExpressibleByArgument {
  public var defaultValueDescription: String {
    "log level"
  }
  public private(set) static var allValueStrings: [String] =
    ["trace", "debug", "info", "notice", "warning", "error", "critical"]

  public private(set) static var defaultCompletionKind: CompletionKind = .default
}
