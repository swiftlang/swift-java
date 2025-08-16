//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift.org project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of Swift.org project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

// Translate all Java Throwable instances in a Swift error.
extension Throwable: Error, CustomStringConvertible {
  public var description: String {
    return toString()
  }
}

extension JavaClass<Throwable> {
  /// Determine whether this instance is a checked exception (which must be
  /// handled) vs. an unchecked exception (which is not handled).
  public var isCheckedException: Bool {
    return !self.is(RuntimeException.self) && !self.is(JavaError.self)
  }
}
