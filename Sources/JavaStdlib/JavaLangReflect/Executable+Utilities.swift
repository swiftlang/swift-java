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

import SwiftJava

extension Executable {
  /// Whether this executable throws any checked exception.
  public var throwsCheckedException: Bool {
    for exceptionType in getExceptionTypes() {
      guard let exceptionType else { continue }
      if let throwableType = exceptionType.as(JavaClass<Throwable>.self) {
        if throwableType.isCheckedException {
          return true
        }
      }
    }

    return false
  }
}
