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
  
  /// Whether this is a 'public' method.
  public var isPublic: Bool {
    return (getModifiers() & 0x00000001) != 0
  }

  /// Whether this is a 'private' method.
  public var isPrivate: Bool {
    return (getModifiers() & 0x00000002) != 0
  }

  /// Whether this is a 'protected' method.
  public var isProtected: Bool {
    return (getModifiers() & 0x00000004) != 0
  }

  /// Whether this is a 'package' method.
  /// 
  /// The "default" access level in Java is 'package', it is signified by lack of a different access modifier.
  public var isPackage: Bool { 
    return !isPublic && !isPrivate && !isProtected
  }

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
