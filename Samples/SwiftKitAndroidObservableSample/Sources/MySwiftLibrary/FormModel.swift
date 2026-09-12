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

import Foundation
import Observation

/// Demonstrates **two-way bindings**: each `var` is read by a Compose
/// `TextField` and written back from its `onValueChange`. `fullName` is a
/// read-only computed property that should recompute (and recompose) whenever
/// `firstName` or `lastName` change.
@Observable
public class FormModel {
  public var firstName: String = ""
  public var lastName: String = ""
  public var email: String = ""
  public var bio: String = ""

  public init() {}

  public var fullName: String {
    let joined = "\(firstName) \(lastName)"
    return joined.trimmingCharacters(in: .whitespaces)
  }

  public var isComplete: Bool {
    !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty
  }

  public func clear() {
    firstName = ""
    lastName = ""
    email = ""
    bio = ""
  }
}
