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

import SwiftJavaJNICore

enum KnownFunctionalInterface {
  case runnable

  init?(_ parameters: [JavaType], _ result: JavaType) {
    switch (parameters, result) {
    case ([], .void):
      self = .runnable
    default:
      return nil
    }
  }

  var javaType: JavaType {
    switch self {
    case .runnable: return JavaType.javaLangRunnable
    }
  }

  var method: String {
    switch self {
    case .runnable: return "run"
    }
  }
}
