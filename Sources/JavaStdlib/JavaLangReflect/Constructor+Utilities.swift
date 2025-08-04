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

extension Constructor {
  /// Whether this is a 'public' constructor.
  public var isPublic: Bool {
    return (getModifiers() & 1) != 0
  }

  /// Whether this is a 'native' constructor.
  public var isNative: Bool {
    return (getModifiers() & 256) != 0
  }
}
