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
    (getModifiers() & 0x0000_0008) != 0
  }

  /// Whether this is a 'native' method.
  public var isNative: Bool {
    (getModifiers() & 0x0000_0100) != 0
  }

  /// Whether this is a 'final' method.
  public var isFinal: Bool {
    (getModifiers() & 0x0000_0010) != 0
  }
}
