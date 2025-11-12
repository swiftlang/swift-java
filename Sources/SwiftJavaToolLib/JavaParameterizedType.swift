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

// E.g. `Another<Bites, The, Dust>`
struct SwiftJavaParameterizedType {
  let name: String
  let typeArguments: [String]

  init?(name: String?, typeArguments: [String]) {
    guard let name else {
      return nil
    }

    self.name = name
    self.typeArguments = typeArguments
  }

  func render() -> String {
    if typeArguments.isEmpty {
      name
    } else {
      "\(name)<\(typeArguments.joined(separator: ", "))>"
    }
  }


}
