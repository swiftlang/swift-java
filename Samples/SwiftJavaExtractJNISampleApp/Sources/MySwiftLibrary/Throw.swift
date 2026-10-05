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

import SwiftJava

// snippet.throwingFunction
public func throwString(input: String) throws -> String {
  if input.isEmpty {
    throw MySwiftError.swiftError
  }
  return input
}
// snippet.end

public func throwTyped(input: String) throws(MySwiftError) -> String {
  if input.isEmpty {
    throw .swiftError
  }
  if input == "invalid" {
    throw .invalidInput(reason: "input was 'invalid'")
  }
  return input
}

// Not public, so it is not extracted and surfaces in Java as `SwiftJavaErrorException`.
struct InternalOnlyError: Error {
  let code: Int
}

public func throwInternalError() throws {
  throw InternalOnlyError(code: 42)
}

public func asyncThrowTyped(input: String) async throws -> String {
  try await Task.sleep(for: .milliseconds(10))
  if input.isEmpty {
    throw MySwiftError.invalidInput(reason: "empty input")
  }
  return input
}
