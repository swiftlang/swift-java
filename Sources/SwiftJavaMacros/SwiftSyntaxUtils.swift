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

import SwiftSyntax

extension FunctionParameterSyntax {
  var argumentName: String? {
    // If we have two names, the first one is the argument label
    if secondName != nil {
      return firstName.text
    }

    // If we have only one name, it might be an argument label.
    if let superparent = parent?.parent?.parent, superparent.is(SubscriptDeclSyntax.self) {
      return nil
    }

    return firstName.text
  }
}
