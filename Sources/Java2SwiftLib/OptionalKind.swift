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

/// Describes the kind of optional type to use.
enum OptionalKind {
  /// The value is nonoptional.
  case nonoptional

  /// The value is optional.
  case optional

  /// The value uses an implicitly-unwrapped optional.
  case implicitlyUnwrappedOptional
}
