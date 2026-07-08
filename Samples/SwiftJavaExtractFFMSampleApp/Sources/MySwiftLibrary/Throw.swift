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

// Mirrors `Throw.swift` in the JNI sample app, so that documentation can show
// one Swift example alongside its usage in both jextract modes

public func throwString(input: String) throws -> String {
  if input.isEmpty {
    throw SwiftExampleError(message: "swiftError")
  }
  return input
}
