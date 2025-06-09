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

extension String {

  // TODO: naive implementation good enough for our simple case `methodMethodSomething` -> `MethodSomething`
  var toCamelCase: String {
    guard let f = first else {
      return self
    }

    return "\(f.uppercased())\(String(dropFirst()))"
  }
}