//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

/// Configures how Swift `async` functions should be extracted by jextract.
public enum JExtractAsyncFuncMode: String, Codable {
  /// Extract Swift `async` APIs as Java functions that return `CompletableFuture`s.
  case completableFuture

  /// Extract Swift `async` APIs as Java functions that return `Future`s.
  ///
  /// This mode is useful for platforms that do not have `CompletableFuture` support, such as
  /// Android 23 and below.
  ///
  /// - Note: Prefer using the `completableFuture` mode instead, if possible.
  case legacyFuture
}

extension JExtractAsyncFuncMode {
  public static var `default`: Self {
    .completableFuture
  }
}
