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

import Foundation
import JavaTypes
import SwiftSyntax

extension ImportedFunc {
  /// Render a `@{@snippet ... }` comment section that can be put inside a JavaDoc comment
  /// when referring to the original declaration a printed method refers to.
  var renderCommentSnippet: String? {
    if let signatureString {
      """
       * {@snippet lang=swift :
       * \(signatureString)
       * }
      """
    } else {
      nil
    }
  }
}
