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

/// Describes an error that can occur when demangling a Java name.
enum JavaDemanglingError: Error {
  /// This does not match the form of a Java mangled type name.
  case invalidMangledName(String)

  /// Extra text after the mangled name.
  case extraText(String)
}
