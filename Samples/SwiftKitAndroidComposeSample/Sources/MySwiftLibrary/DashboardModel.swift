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

/// A view model with **many observable states** of different primitive types.
/// Each property drives a different Compose control (text, slider, switch,
/// stepper). Only the property that actually changed should recompose the
/// widgets that read it.
@Observable
public class DashboardModel {
  public var title: String = "My Dashboard"
  public var counter: Int64 = 0
  public var level: Int32 = 1
  public var temperature: Double = 20.5
  public var progress: Double = 0.25
  public var isEnabled: Bool = true
  public var isFavorite: Bool = false

  public init() {}

  public func increment() { counter += 1 }
  public func decrement() { counter -= 1 }
  public func levelUp() { level += 1 }
  public func warmer() { temperature += 0.5 }
  public func cooler() { temperature -= 0.5 }
  public func toggleEnabled() { isEnabled.toggle() }
  public func toggleFavorite() { isFavorite.toggle() }

  public func reset() {
    counter = 0
    level = 1
    temperature = 20.5
    progress = 0.25
    isEnabled = true
    isFavorite = false
  }
}
