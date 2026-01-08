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
    return (getModifiers() & 0x00000008) != 0
  }

  /// Whether this is a 'native' method.
  public var isNative: Bool {
    return (getModifiers() & 0x00000100) != 0
  }
  
  /// Whether this is a 'final' method.
  public var isFinal: Bool {
    return (getModifiers() & 0x00000010) != 0
  }
}
