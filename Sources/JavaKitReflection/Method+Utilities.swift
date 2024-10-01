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

extension Method {
  /// Whether this is a 'static' method.
  public var isStatic: Bool {
    return (getModifiers() & 0x08) != 0
  }

  /// Whether this executable throws any checked exception.
  public var throwsCheckedException: Bool {
    return self.as(Executable.self)!.throwsCheckedException
  }
}
