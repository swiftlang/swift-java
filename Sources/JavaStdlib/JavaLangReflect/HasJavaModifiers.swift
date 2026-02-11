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

import SwiftJava

public protocol HasJavaModifiers {
  func getModifiers() -> Int32
}

extension HasJavaModifiers {
  /// Whether the modifiers contain 'public'.
  public var isPublic: Bool {
    (getModifiers() & 0x0000_0001) != 0
  }

  /// Whether the modifiers contain 'private'.
  public var isPrivate: Bool {
    (getModifiers() & 0x0000_0002) != 0
  }

  /// Whether the modifiers contain 'protected'.
  public var isProtected: Bool {
    (getModifiers() & 0x0000_0004) != 0
  }

  /// Whether the modifiers is equivelant to 'package'..
  ///
  /// The "default" access level in Java is 'package', it is signified by lack of a different access modifier.
  public var isPackage: Bool {
    !isPublic && !isPrivate && !isProtected
  }
}

extension Constructor: HasJavaModifiers {}
extension JavaClass: HasJavaModifiers {}
extension Method: HasJavaModifiers {}
