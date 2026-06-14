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

import Observation

/// Exercises the things that should **NOT** participate in observation:
///
/// - `static let` / `static var`: type-level, never tracked per-instance.
/// - `let`: immutable stored property; `@Observable` does not track it.
/// - `@ObservationIgnored var`: explicitly opted out of tracking.
///
/// Only `visibleCounter` is a normal observed `var`. The UI should recompose
/// when `visibleCounter` changes, but NOT when `hiddenCounter` changes — even
/// though `hiddenCounter` really is mutating under the hood (which we can prove
/// by copying it into `visibleCounter`, forcing a legitimate refresh).
@Observable
public class EdgeCasesModel {
  /// Type-level constant — must not generate any per-instance observation.
  public static let appName: String = "SwiftJava Observable Sample"

  /// Type-level mutable — also must not be observed per instance.
  public static var launchCount: Int64 = 0

  /// Immutable stored property — never changes, so must not be observed.
  public let createdLabel: String = "Created once at init"

  /// Explicitly excluded from observation tracking.
  @ObservationIgnored public var hiddenCounter: Int64 = 0

  /// The only genuinely observed property.
  public var visibleCounter: Int64 = 0

  public init() {
    EdgeCasesModel.launchCount += 1
  }

  /// Mutates an ignored property — the UI should NOT react to this.
  public func bumpHidden() { hiddenCounter += 1 }

  /// Mutates an observed property — the UI SHOULD react to this.
  public func bumpVisible() { visibleCounter += 1 }

  /// Pulls the (silently changed) hidden value into the observed one, so a
  /// real notification fires and the UI finally reflects the hidden mutations.
  public func revealHidden() { visibleCounter = hiddenCounter }
}
