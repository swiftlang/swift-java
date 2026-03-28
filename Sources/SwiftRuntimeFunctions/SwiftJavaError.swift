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

/// Wraps a Swift `any Error` value so it can be passed across the FFI boundary
/// as a reference-counted heap object
public final class SwiftJavaError {
  public let underlying: any Error

  public init(_ error: any Error) {
    self.underlying = error
  }

  /// Human-readable description of the underlying error
  public func errorDescription() -> String {
    String(describing: underlying)
  }

  /// Metatype pointer for the underlying error's dynamic type
  public func errorType() -> UnsafeRawPointer {
    unsafeBitCast(type(of: underlying), to: UnsafeRawPointer.self)
  }
}

